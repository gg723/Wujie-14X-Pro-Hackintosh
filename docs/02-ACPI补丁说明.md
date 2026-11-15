# 02 · ACPI 补丁说明（触摸板 TPD0）

这一节是本仓库最核心的改动，也是唯一一处「必须这样做、否则开不了机」的地方。

---

## 一、问题：触摸板连「设备」都不算

反编译 DSDT 后，`\_SB.I2CD.TPD0` 的定义大致是：

```asl
Device (TPD0)
{
    Method (_HID, 0, NotSerialized)
    {
        If (H_EC.ECRD (TPAD) == 0x01) { Return ("BLTP0258") }
        If (H_EC.ECRD (TPAD) == 0x02) { Return ("HTIX528C") }
        Return ("")
    }

    Method (_STA, 0, NotSerialized)
    {
        If (H_EC.ECRD (TPAD) == 0) { Return (0) }   // ← 返回 0 = 设备不存在
        Else { Return (0x0F) }
    }

    Method (_CRS, 0, ...)
    {
        Name (RBUF, ResourceTemplate ()
        {
            I2cSerialBus (0x2C, ControllerInitiated, 0x00061A80,
                          AddressingMode7Bit, "\\_SB.I2CD", ...)
            GpioInt (Edge, ActiveLow, Exclusive, PullDefault, 0,
                     "\\_SB.GPIO", 0, ResourceConsumer, , ) { 0x23 }
        })
        Return (RBUF)
    }
}
```

而读取函数本身还有一道闸：

```asl
Method (ECRD, 1)
{
    If (ECAV) { Return (DerefOf (Arg0)) }
    Return (Zero)          // ECAV == 0 时，一律返回 0
}
```

`ECAV` 初始为 0，只有 macOS 的 EC 驱动真正接管 EmbeddedControl 区域后才置 1。
**EC 没被接管 → `ECRD` 恒返回 0 → `_STA` 恒返回 0 → 系统认为「这台机器没有触摸板」。**

这就是「触摸板完全不能用」的根因，跟 kext 放没放、VoodooI2C 配没配都无关。

---

## 二、处理方式：等长改名 + SSDT 重新定义

### 为什么不能直接替换方法体

OpenCore 源码 `Library/OcMainLib/OpenCoreAcpi.c`：

```c
if (  (UserPatch->Replace.Size == 0)
   || ((UserPatch->Find.Size > 0) && (UserPatch->Find.Size != UserPatch->Replace.Size))
   ... )
{
  DEBUG ((DEBUG_ERROR, "OC: ACPI patch (%a) at %u is borked\n", Comment, Index));
  continue;
}
```

**`Find` 与 `Replace` 必须严格等长。** 用「整段方法替换」的写法，

- 原 `_STA` 方法 61 字节 → 新方法体 10 字节
- 原 `_HID` 方法 125 字节 → 18 字节
- 原 `_CRS` 方法 88 字节 → 51 字节

全部不等长 → 打印 `is borked` → `Halting on critical error` → **开机黑屏停机**。
本仓库的第一版就是这么挂的，别重犯。

### 现在的三条补丁

只把方法名换掉，字节数完全不变：

| # | Comment | Find | Replace |
|---|---|---|---|
| 1 | `TPD0 _STA -> XSTA` | 61 B | 61 B |
| 2 | `TPD0 _HID -> XHID` | 125 B | 125 B |
| 3 | `TPD0 _CRS -> XCRS` | 88 B | 88 B |

三条 `Find` 字节在 DSDT 中都**唯一匹配**（各出现 1 次），不会误伤别处。

### `SSDT-TPD0.aml`

改名之后原方法消失，由 SSDT 在同一个 Scope 里补上新的三个方法：

```asl
DefinitionBlock ("", "SSDT", 2, "PHXTPD", "TPD0", 0x00000001)
{
    External (_SB_.I2CD, DeviceObj)
    External (_SB_.I2CD.TPD0, DeviceObj)

    Scope (_SB_.I2CD.TPD0)
    {
        Method (_STA, 0, NotSerialized) { Return (0x0F) }

        Method (_HID, 0, NotSerialized) { Return ("HTIX528C") }

        Method (_CRS, 0, Serialized)
        {
            Name (RBUF, ResourceTemplate ()
            {
                I2cSerialBus (0x002C, ControllerInitiated, 0x00061A80,
                    AddressingMode7Bit, "\\_SB.I2CD",
                    0x00, ResourceConsumer, , )
            })
            Return (RBUF)
        }
    }
}
```

两个细节：

1. **`_CRS` 用 `I2cSerialBus`（V1，类型字节 `0x01`）**，与固件原字节逐字节一致。
   iasl 默认输出 `I2cSerialBusV2`（`0x02`），虽然通常也能用，但没必要引入差异。
2. **去掉 `GpioInt`**。中断挂在 `\_SB.GPIO`（`AMDI0030`，AMD 私有 GPIO），
   而 `VoodooGPIO` 只支持 Intel GPIO 控制器，中断永远拿不到。
   去掉后 `VoodooI2C` 自动退回**轮询**——能用，但不如中断跟手。

### 本地验证方法（建议每次改补丁都做）

把三条补丁实际打进 DSDT 二进制，再反编译检查：

```bash
python - <<'PY'   # 按 config 里的 Find/Replace 做字节替换
PY
iasl -d DSDT_patched.aml     # 确认 XSTA/XHID/XCRS 落位、表长不变、零错误
```

> ⚠️ `iasl -d X.aml` 会**覆盖同名 `.dsl`**。源文件请另存，或在独立目录里反编译。

---

## 三、安全阀

`Misc → Boot → HaltLevel` 设为 **0**。

含义：ACPI 补丁出问题时只记录、**不停机**。代价是「静默失败」，
所以排错时改成 `0x80000000`（只报错不停）或临时打开 `-v` 看日志更直接。

---

## 四、其它 ACPI 表

| 表 | 作用 |
|---|---|
| `SSDT-EC-USBX-LAPTOP.aml` | 补 EC 与 USBX（供电属性） |
| `SSDT-PLUG-ALT.aml` | 注入 `plugin-type=1`，让 X86PlatformPlugin 接管电源管理 |
| `SSDT-PHXBKL.aml` | 背光相关（配合 nullarc 的 `PhxBacklight`） |
| `SSDT-BAT.aml` | 电池（配套 `_BIX→XBIX`、`_BST→XBST` 两条等长改名补丁） |
| `SSDT-ENTP.aml` | 未启用，保留 |
| `SSDT-TPD0.aml` | 本文件，触摸板 |
