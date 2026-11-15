/*
 * SSDT-TPD0 —— 触摸板热补丁（源文件，勿用 iasl -d 覆盖）
 *
 * 目的：绕开 EC 门禁，让 \_SB.I2CD.TPD0 作为 PNP0C50 设备被 macOS 枚举；
 *       并把 _CRS 里的 GpioInt(AMDP0030/AMDI0030) 去掉，令 VoodooI2C 退化为轮询。
 *
 * 配套 ACPI Patch 三条（等长改名，OpenCore 要求 Find.Size == Replace.Size）：
 *   TPD0 _STA -> XSTA
 *   TPD0 _HID -> XHID
 *   TPD0 _CRS -> XCRS
 *
 * 资源描述符刻意用 I2cSerialBus（V1，类型 0x01），与固件原 _CRS 字节一致；
 * 不用 V2（0x02），避免引入无必要的差异。
 */
DefinitionBlock ("", "SSDT", 2, "PHXTPD", "TPD0", 0x00000001)
{
    External (_SB_.I2CD, DeviceObj)
    External (_SB_.I2CD.TPD0, DeviceObj)

    Scope (_SB_.I2CD.TPD0)
    {
        Method (_STA, 0, NotSerialized)
        {
            Return (0x0F)
        }

        Method (_HID, 0, NotSerialized)
        {
            Return ("HTIX528C")
        }

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
