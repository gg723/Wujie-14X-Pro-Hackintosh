/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (32-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of SSDT-PHXBKL.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x0000009D (157)
 *     Revision         0x02
 *     Checksum         0xDD
 *     OEM ID           "PHX"
 *     OEM Table ID     "PHXBKL"
 *     OEM Revision     0x00000001 (1)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20260930 (539363632)
 */
DefinitionBlock ("", "SSDT", 2, "PHX", "PHXBKL", 0x00000001)
{
    External (_SB_.PCI0, DeviceObj)

    Scope (_SB.PCI0)
    {
        Device (BKL)
        {
            Name (_HID, "APP0002")  // _HID: Hardware ID
            Name (_CID, "backlight")  // _CID: Compatible ID
            Name (_UID, One)  // _UID: Unique ID
            Name (_STA, 0x0B)  // _STA: Status
            Method (_BCL, 0, NotSerialized)  // _BCL: Brightness Control Levels
            {
                Return (Package (0x0B)
                {
                    0x64, 
                    Zero, 
                    0x0A, 
                    0x14, 
                    0x1E, 
                    0x28, 
                    0x32, 
                    0x3C, 
                    0x46, 
                    0x50, 
                    0x5A
                })
            }

            Method (_BCM, 1, NotSerialized)  // _BCM: Brightness Control Method
            {
                Local0 = Arg0
            }
        }
    }
}

