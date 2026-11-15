/*
 * Intel ACPI Component Architecture
 * AML/ASL+ Disassembler version 20260408 (32-bit version)
 * Copyright (c) 2000 - 2026 Intel Corporation
 * 
 * Disassembling to symbolic ASL+ operators
 *
 * Disassembly of SSDT-ENTP.aml
 *
 * Original Table Header:
 *     Signature        "SSDT"
 *     Length           0x00000146 (326)
 *     Revision         0x02
 *     Checksum         0x04
 *     OEM ID           "OCLT"
 *     OEM Table ID     "TPDEN"
 *     OEM Revision     0x00000000 (0)
 *     Compiler ID      "INTL"
 *     Compiler Version 0x20250807 (539297799)
 */
DefinitionBlock ("", "SSDT", 2, "OCLT", "TPDEN", 0x00000000)
{
    External (_SB_.I2CD.TPD0, DeviceObj)
    External (_SB_.I2CD.TPD0._DSM, MethodObj)    // 4 Arguments
    External (_SB_.PCI0.LPC0.H_EC, DeviceObj)
    External (_SB_.PCI0.LPC0.H_EC.ECWT, MethodObj)    // 2 Arguments
    External (_SB_.PCI0.LPC0.H_EC.ENTP, FieldUnitObj)
    External (_SB_.PCI0.LPC0.H_EC.WITP, FieldUnitObj)

    Scope (\_SB.I2CD.TPD0)
    {
        Method (XDSM, 4, NotSerialized)
        {
            \_SB.PCI0.LPC0.H_EC.ECWT (One, RefOf (\_SB.PCI0.LPC0.H_EC.WITP))
            \_SB.PCI0.LPC0.H_EC.ECWT (One, RefOf (\_SB.PCI0.LPC0.H_EC.ENTP))
            Return (\_SB.I2CD.TPD0._DSM (Arg0, Arg1, Arg2, Arg3))
        }
    }
}

