# 无界 14X Pro (Wujie 14X Pro) Hackintosh — OpenCore EFI

机械革命 **无界 14X Pro** / AMD Ryzen 7 H255 + Radeon 780M 的黑苹果 EFI，
系统为 **macOS Tahoe 26**，机型伪装 `MacBookPro16,1`。

> 这是**实测可用**的一份 EFI，不是从别处抄来未验证的模板。
> 本机已进入系统、可正常使用；功能矩阵见下表，**未通过的项目我标了「未验证」或「不支持」，没有美化**。

---

## 一、硬件

| 项目 | 型号 | 备注 |
|---|---|---|
| 机型 | 机械革命 无界 14X Pro | 固件 EDK2 |
| CPU | AMD Ryzen 7 H255 | 8 核 16 线程 (Zen 4) |
| 核显 | AMD Radeon 780M | RDNA3 / gfx1103 |
| 内屏 | 天马 TL140ADXP26 (TMA2066) | 14" 2880×1800 16:10，48–120 Hz，eDP 8bit |
| 无线网卡 | Intel Wi-Fi 6E AX210 | `8086:2725` |
| 有线网卡 | Realtek RTL8168/8111 | `10ec:8168` rev 15 |
| 触摸板 | Hynitron 触控芯片 | `_HID=HTIX528C` / `_CID=PNP0C50`，I2C 挂在 `\_SB.I2CD` |
| 声卡 | AMD HDA | `layout-id=21` |
| 蓝牙 | AX210 内置 | `USB\VID_8087&PID_0032` |

---

## 二、功能状态

| 项目 | 状态 | 说明 |
|---|---|---|
| 系统启动 | ✅ 可用 | OpenCore 1.x，`Secure Boot` 必须关闭 |
| 内屏显示 | ✅ 可用 | 分辨率为固件点亮的 2880×1800，见「显示」一节 |
| GPU 加速（Metal） | ✅ 可用 | 依赖第三方项目 **nullarc**；仓库只附带引导辅助件，**加速本体需自行安装**（见四、4） |
| 有线网络 | ✅ 可用 | `RealtekRTL8111.kext` v3.0.4（含 AppleVTD/Tahoe 修正） |
| 无线网络 | ✅ 可用 | `itlwm.kext` 2.3.0 + **HeliPort.app**（需另装，见下） |
| 蓝牙 | ✅ 可用 | 需 `-ibtcompatbeta` 启动参数，见第四节 |
| 触摸板 | 🟡 可用（轮询） | 见第三节，**无中断**，手感比原生略钝 |
| 键盘 / 亮度键 | ✅ 可用 | |
| 声音输出 | ✅ 可用 | `alcid=21` |
| 麦克风 | 🟡 未完全验证 | 输入设备枚举不稳定，属遗留项 |
| 屏幕亮度 | 🟡 硬件 PWM 可用 | 依赖 GPU 组件里的背光实现，PWM 不通时会退软件调光（有延迟） |
| 外接显示器 | ❌ 不支持 | HDMI / Type-C DP 均无输出，见第五节 |
| 睡眠 / 合盖 | ⚠️ 未验证 | 建议先关闭自动睡眠 |
| USB-C 插拔 | ⚠️ 有卡顿 | 插拔后系统可能卡 20~30 秒 |

---

## 三、这个 EFI 里做了什么（与通用 EFI 的差异）

### 1. 触摸板：`TPD0` 三道 ACPI 补丁（关键）

DSDT 里触摸板的 `_STA` 是这样的：

```asl
Method (_STA) {
    If (H_EC.ECRD(TPAD) == 0) { Return (0) }   // EC 读不到就返回 0
    Else { Return (0x0F) }
}
```

而 `ECRD` 有一道闸门 `If (ECAV)` —— EC 没被 macOS 接管时恒返回 0，
于是系统认为「这台机器没有触摸板」，设备**根本不会出现**。

处理方式（注意顺序，这里踩过坑）：

1. **三条等长改名补丁**，只把方法名换掉，不动任何字节数：
   `_STA → XSTA`（61→61）、`_HID → XHID`（125→125）、`_CRS → XCRS`（88→88）
2. 再用 **`SSDT-TPD0.aml`** 在 `Scope(\_SB.I2CD.TPD0)` 里重新定义这三个方法：
   - `_STA` 恒返回 `0x0F`
   - `_HID` 写死 `"HTIX528C"`
   - `_CRS` **只保留 I2C SerialBus，去掉 `GpioInt`**

> ⚠️ **为什么必须等长**：OpenCore 源码 `Library/OcMainLib/OpenCoreAcpi.c` 里明确规定，
> `Find.Size != Replace.Size` 就判定 `ACPI patch ... is borked`，然后
> **`Halting on critical error` 直接停机**。用「整段替换方法体」的写法长度必然不等，
> 就开不了机（这个仓库第一版就是这么挂的）。
>
> 另外 `_CRS` 里的 I2C 描述符要用 **V1**（`I2cSerialBus`，类型字节 `0x01`）与固件原字节一致；
> iasl 默认生成 V2（`0x02`），虽然通常也能用，但没必要引入差异。

去掉 `GpioInt` 的原因：中断挂在 `\_SB.GPIO`（`AMDI0030`，AMD 私有 GPIO）上，
而 `VoodooGPIO` 只支持 Intel 的 GPIO 控制器，中断永远拿不到。
去掉后 `VoodooI2C` 会自动退回**轮询**——能用，但手感不如中断模式。

### 2. 安全阀：`Misc → Boot → HaltLevel = 0`

任何 ACPI 补丁再出问题，OpenCore 只跳过那一条、继续引导，**不会再停在一个黑屏上**。
强烈建议保留。

### 3. 蓝牙：`-ibtcompatbeta`

`IntelBTPatcher` 的版本上限写死在 Sequoia，在 Tahoe 上会被 Lilu 的版本检查拦下、
**整个 kext 不加载**，固件传不上去 → 蓝牙不可用。加这个参数跳过版本检查即可，无需改 kext。

### 4. 启动参数全量

```
-v keepsyms=1 revpatch=cpuname,sbvmm ipc_control_port_options=0
-amfipassbeta amfi=0x80 amfi_get_out_of_my_way=0x1
phxdebug=1 alcid=21 -nohe -ibtcompatbeta
```

| 参数 | 作用 | 副作用 |
|---|---|---|
| `-v keepsyms=1` | 开机滚屏 + 保留符号，排错用 | 无（稳定后可删掉 `-v`） |
| `revpatch=cpuname` | CPU 名称显示正确 | 无 |
| `amfi=0x80` + `amfi_get_out_of_my_way=0x1` | 允许加载未签名 GPU 驱动 | **FairPlay 视频（Netflix 等）失效**，这是代价 |
| `-amfipassbeta` | AMFIPass 兼容开关 | 无 |
| `phxdebug=1` | GPU 组件调试日志 | 日志变多 |
| `alcid=21` | 声卡布局 | 无 |
| `-nohe` | 关闭 HE（nullarc 要求） | 无 |
| `-ibtcompatbeta` | 跳过 Intel 蓝牙的版本上限 | 无 |

---

## 四、怎么用

### 0. 前提

- **BIOS 里必须关闭 Secure Boot**（否则 OpenCore 起不来）
- 建议同时关闭 `Above 4G Decoding` 的相关限制项、开启 `VT-d=off`
- 准备一个 ≥16GB 的 U 盘

### 1. 生成你自己的 SMBIOS（**必做**）

本仓库的 `config.plist` 里序列号 / MLB / UUID / ROM **已被置空或替换为占位值**，
直接使用会没有 iCloud / iMessage，且多台机器共用一个占位值是不对的。

用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)（macOS 或 Windows 都能跑）：

1. 选项 `1` 下载/更新 MacSerial
2. 选项 `3` 生成 SMBIOS，机型填 **`MacBookPro16,1`**
3. 把输出的 `Serial` / `MLB` / `SmUUID` 填进 `config.plist → PlatformInfo → Generic`
4. `ROM` 填你自己网卡的 6 字节 MAC 地址（十六进制）

### 2. 放进 ESP 并启动

```
U盘或硬盘 ESP
└─ EFI
   ├─ BOOT
   │  └─ BOOTx64.efi
   └─ OC
      ├─ ACPI/     ← 含 SSDT-TPD0.aml 等 6 个表
      ├─ Kexts/    ← 24 个 kext
      ├─ config.plist
      └─ OpenCore.efi
```

### 3. 无线网络

`itlwm.kext` **不会**让 Wi-Fi 出现在系统菜单栏里，必须配合
[HeliPort](https://github.com/OpenIntelWireless/HeliPort/releases)（`2.0.0-alpha` 及以后）。
第一次打开 HeliPort 要 **右键 → 打开**，否则会被 Gatekeeper 拦住。

### 4. GPU 加速（必需，否则只能用软件渲染）

内屏加速走的是第三方项目 **nullarc**（Metal → Vulkan 转译）。
请去上游获取完整包并按其文档安装：`https://github.com/luuumi-dev/nullarc`

本机实测可用的组合：`PhxBringup` + `PhxAccel` + `PhxAGDC` + `PhxBacklight`，
配合仓库里的 `SSDT-PHXBKL.aml` 与 `phxdebug=1`。

**关于本仓库附带的部分**：`EFI/OC/Kexts` 里的 `PhxBringup`、`PhxGpioProbe`、`PhxXhciKick`
来自 nullarc（MIT 许可，可再分发），属于引导辅助件。
**加速本体 `PhxAccel.kext`、`NVMTLDriver.bundle`、Mesa RADV 以及 GPU 固件一律未打包** ——
它们受 PolyForm Noncommercial 1.0.0 与 AMD 微码条款约束（详见 `NOTICE`）。
所以光用本仓库的 EFI 只会**以软件渲染运行**，要加速必须自己去上游装。

> 回退办法：`sudo touch /Users/Shared/gpu/phxboot-off` 后重启，回到纯软件渲染。

---

## 五、已知限制（明确做不到的）

### 外接显示器：不支持

本项目用的 GPU 方案是「**接管固件已经点亮的那一块扫描输出**」，不是一个完整的
显示驱动。它没有实现：

- HPD（热插拔检测）→ 通知 WindowServer
- 通过 AUX/DDC 读外接屏 EDID
- DP 链路训练（CR/EQ）与 DMUB 固件
- 第二路 DCN pipeline 的 PHY / 编码器

所以 HDMI 与 Type-C 的 DP alt mode **都不会出画面**，插 dummy plug 也没用。
这不是配置问题，是这套方案的实现边界。上游 `KNOWN_ISSUES.md` 的 `B-11` 条目明确写着
「外接显示器进行中」，正在按 Linux 内核 `amdgpu/display` 逐行移植 DCN 3.1.4。

**短期替代**：DisplayLink USB 扩展坞（走 USB 数据通路，绕开 DCN），
代价是需要「屏幕录制」权限、无 HDCP、不适合游戏。

### 显示分辨率档位少

内屏的模式来自固件点亮的画面，只有 2880×1800 一档；EDID 里也只声明了一个 DTD，
所以「显示器」里的缩放档位偏少。

系统的隐藏档位可以按住 **Option(⌥)** 再点「缩放」展开。
要加更多自定义档位，用系统自带的
`/Library/Displays/Contents/Resources/Overrides/` 机制（见 `docs/`），
不需要第三方 App。

### 触摸板手感

轮询模式，两指/三指手势可用，但精细拖拽不如原生跟手。根因是没有 AMD GPIO
（`AMDI0030`）的 macOS 驱动，这一步不在本仓库能解决的范围内。

---

## 六、目录结构

```
EFI/                    OpenCore 引导文件（可直接拷进 ESP）
docs/
  01-硬件与EDID.md       内屏 EDID 原始数据与解析
  02-ACPI补丁说明.md     TPD0 三条补丁 + SSDT 的完整原理
  03-安装与排错.md       安装步骤、borked 停机怎么救、回退
  04-已知问题.md         逐项说明与判定方法
LICENSE                 MIT（仅覆盖本仓库的文档与配置改动）
NOTICE                  第三方组件与许可证
```

---

## 七、致谢

- [OpenCore](https://github.com/acidanthera/OpenCorePkg) 及 Acidanthera 全家桶
- [itlwm / HeliPort](https://github.com/OpenIntelWireless) — OpenIntelWireless
- [RealtekRTL8111](https://github.com/Mieze/RTL8111_driver_for_OS_X) — Mieze
- [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C)
- [nullarc](https://github.com/luuumi-dev/nullarc) — 780M 的 Metal 转译层
- 各 kext 版权归原作者，许可证见 `NOTICE`

## 八、免责声明

刷写 EFI 有风险，可能造成系统无法启动或数据丢失。**请自行备份重要数据**。
本仓库按「现状」提供，不对任何直接或间接损失负责。
不同批次的同型号机器可能使用不同面板/网卡，请先核对自己的硬件 ID。
