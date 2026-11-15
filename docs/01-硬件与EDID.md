# 01 · 硬件与内屏 EDID

## 整机

| 项目 | 值 |
|---|---|
| 机型 | 机械革命 无界 14X Pro |
| 固件 | EDK2（AMI 风格的 UEFI，Setup 里可关 Secure Boot） |
| CPU | AMD Ryzen 7 H255（8C/16T，Zen 4） |
| 核显 | AMD Radeon 780M（RDNA3，`gfx1103`，PCI `1002:15bf`） |
| 内存 | 共享显存（UMA），BIOS 里 UMA 预留偏大 |

## 总线设备

| 设备 | 标识 | 备注 |
|---|---|---|
| 无线 | `8086:2725` | Intel Wi-Fi 6E AX210 |
| 有线 | `10ec:8168` rev 15 | Realtek RTL8168/8111 |
| 蓝牙 | `USB\VID_8087&PID_0032` | 挂在 XHC0 的 `WLAN` 端口（port 5，Internal） |
| 触摸板 | `_HID = HTIX528C`，`_CID = PNP0C50` | Hynitron，I2C 地址 `0x2C`，挂在 `\_SB.I2CD` |
| 触摸板中断 | `GpioInt` → `\_SB.GPIO`（`AMDI0030`） | **macOS 无此 GPIO 驱动**，故补丁里去掉了 |
| 声卡 | AMD HDA，`layout-id = 21` | AppleALC + SimpleHDA |

## 内屏

| 项目 | 值 |
|---|---|
| 面板 | 天马 **TL140ADXP26** |
| EDID 厂商 / 产品码 | `TMA`（`0x0E77`? 见下 EDID）/ 产品码 `0x2066` |
| 尺寸 | 30 × 19 cm，对角 35.5 cm = **14.0 英寸** |
| 原生分辨率 | **2880 × 1800**（16:10） |
| 刷新率范围 | **48 – 120 Hz** |
| 最大像素时钟 | 700 MHz |
| 制造周 | 2024 年第 26 周 |
| 接口 | eDP，8 bit |

### 原始 EDID（前 128 字节）

```
00 FF FF FF FF FF FF 00  ...（厂商与产品信息）
```

完整数据见本目录 `EDID-internal.txt`。

### 关键解析结论

1. **EDID 里只有一个 DTD**：2880×1800@60。
   已建立时序全为 0，16 字节标准时序全是 `01 01`（未使用）。
   也就是说这块屏**只自报一个模式**，其余全靠驱动按 range limits 生成。

2. **2880×1800@120Hz 需要约 696.4 MHz 像素时钟**（3040 × 1909 × 120），
   上限 700 MHz —— 贴着跑，没有余量。

3. 因此「显示器」里的缩放档位少，是**数据源只有一档**导致的，
   与伪装机型 `MacBookPro16,1` 无关（档位由 framebuffer 上报的模式列表算出来，
   SMBIOS 机型名不参与这个计算）。

### 为什么 EDID 注入没用

本机的 GPU 组件（`PhxAMDFB`）是**接管固件已经点亮的扫描输出**，
二进制里 `EDID` / `i2c` / `ddc` / `HPD` 关键字命中数**全为 0** ——
它既不读 EDID，也就不存在「注入一份就会被采用」的通道。
想改分辨率只能走系统侧的 Display Overrides（见 `04-已知问题.md`）。
