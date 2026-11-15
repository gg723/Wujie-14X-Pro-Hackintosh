/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (32-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of SSDT-BAT.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x000003C5 (965)
 *     Revision         0x02
 *     Checksum         0xC3
 *     OEM ID           "RAPID"
 *     OEM Table ID     "BAT"
 *     OEM Revision     0x00000001 (1)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20250404 (539296772)
 */
DefinitionBlock ("", "SSDT", 2, "RAPID", "BAT", 0x00000001)
{
    External (_SB_.PCI0.LPC0.H_EC, DeviceObj)
    External (_SB_.PCI0.LPC0.H_EC.BAT0, DeviceObj)
    External (_SB_.PCI0.LPC0.H_EC.BAT0.XBIX, MethodObj)    // 0 Arguments
    External (_SB_.PCI0.LPC0.H_EC.BAT0.XBST, MethodObj)    // 0 Arguments
    External (_SB_.PCI0.LPC0.H_EC.ECRD, MethodObj)    // 1 Arguments
    External (_SB_.PCI0.LPC0.H_EC.ECWR, FieldUnitObj)
    External (_SB_.PCI0.LPC0.H_EC.SMCE, FieldUnitObj)

    Method (B2IN, 2, NotSerialized)
    {
        Local0 = Zero
        Local1 = Zero
        While ((Local1 < Arg1))
        {
            Local0 |= (DerefOf (Arg0 [Local1]) << (Local1 * 0x08)
                )
            Local1++
        }

        Return (Local0)
    }

    Scope (\_SB.PCI0.LPC0.H_EC)
    {
        Method (RM1B, 1, NotSerialized)
        {
            OperationRegion (RREG, SystemMemory, Arg0, One)
            Field (RREG, ByteAcc, NoLock, Preserve)
            {
                BYTE,   8
            }

            Return (BYTE) /* \_SB_.PCI0.LPC0.H_EC.RM1B.BYTE */
        }

        Method (RMCB, 2, Serialized)
        {
            Local0 = Arg0
            Local1 = (Arg1 >> 0x03)
            Name (BBUF, Buffer (Local1){})
            Local2 = Zero
            While ((Local2 < Local1))
            {
                BBUF [Local2] = RM1B (Local0)
                Local0++
                Local2++
            }

            Return (BBUF) /* \_SB_.PCI0.LPC0.H_EC.RMCB.BBUF */
        }
    }

    Scope (\_SB.PCI0.LPC0.H_EC.BAT0)
    {
        Method (_BIX, 0, Serialized)  // _BIX: Battery Information Extended
        {
            If (_OSI ("Darwin"))
            {
                Name (BPK1, Package (0x15)
                {
                    One, 
                    Zero, 
                    0xFFFFFFFF, 
                    0xFFFFFFFF, 
                    One, 
                    0xFFFFFFFF, 
                    Zero, 
                    Zero, 
                    0x64, 
                    0x00017318, 
                    Zero, 
                    Zero, 
                    Zero, 
                    Zero, 
                    0x64, 
                    Zero, 
                    "SR Real Battery", 
                    "123456789", 
                    "Li-ion", 
                    "LiP", 
                    One
                })
                Local0 = (B2IN (RMCB (0xFE800464, 0x10), 0x02) * 0x0A)
                BPK1 [0x02] = Local0
                Local1 = (B2IN (RMCB (0xFE800468, 0x10), 0x02) * 0x0A)
                BPK1 [0x03] = Local1
                If ((Local1 != Zero))
                {
                    BPK1 [0x06] = (Local1 / 0x0A)
                    BPK1 [0x07] = (Local1 / 0x19)
                }

                BPK1 [0x05] = B2IN (RMCB (0xFE800470, 0x10), 0x02)
                BPK1 [0x08] = B2IN (RMCB (0xFE800474, 0x10), 0x02)
                BPK1 [0x10] = ToString (RMCB (0xFE8004B0, 0x80), Ones)
                BPK1 [0x11] = ToHexString (B2IN (RMCB (0xFE800462, 0x10), 0x02))
                BPK1 [0x13] = ToString (RMCB (0xFE8004C0, 0x80), Ones)
                Return (BPK1) /* \_SB_.PCI0.LPC0.H_EC.BAT0._BIX.BPK1 */
            }
            Else
            {
                Return (XBIX ())
            }
        }

        Method (_BST, 0, NotSerialized)  // _BST: Battery Status
        {
            If (_OSI ("Darwin"))
            {
                Name (PKG1, Package (0x04)
                {
                    Ones, 
                    Ones, 
                    Ones, 
                    Ones
                })
                Local0 = Zero
                If ((ECRD (RefOf (ECWR)) & 0x04))
                {
                    Local0 = 0x02
                }
                ElseIf ((ECRD (RefOf (ECWR)) & 0x08))
                {
                    Local0 = One
                }

                If ((ECRD (RefOf (ECWR)) & 0x10))
                {
                    Local0 |= 0x04
                }

                If ((ECRD (RefOf (SMCE)) & One))
                {
                    Local0 |= 0x08
                }

                Local1 = B2IN (RMCB (0xFE80046C, 0x10), 0x02)
                Local2 = B2IN (RMCB (0xFE80046E, 0x10), 0x02)
                Local3 = B2IN (RMCB (0xFE800470, 0x10), 0x02)
                PKG1 [Zero] = Local0
                PKG1 [One] = (Local1 * 0x0A)
                PKG1 [0x02] = (Local2 * 0x0A)
                PKG1 [0x03] = Local3
                Return (PKG1) /* \_SB_.PCI0.LPC0.H_EC.BAT0._BST.PKG1 */
            }
            Else
            {
                Return (XBST ())
            }
        }
    }
}

