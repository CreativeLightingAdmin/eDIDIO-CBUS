# CBUS NAC Control Freak® eDIDIO Library

**Firmware Version**: 1.1.0  
**Release Date**: 2024-09-02

## Introduction

The **Control Freak® eDIDIO Lua Library** provides a straightforward way to control **DALI** and **DMX** lighting interfaces via **TCP/IP** from a **CBUS NAC (5500NAC)** device.

This guide outlines how to configure your hardware and integrate the library into the CBUS scripting environment for lighting control.

---

## Hardware Requirements

To use this library, ensure the following:

- The **eDIDIO controller** must be:
  - Powered by a **24V DC power supply**
  - On the **same IP network** as the CBUS NAC
  - Properly configured with TCP/IP settings for communication with the NAC

### DALI Notes

- If your eDIDIO has **DALI output**, it **requires a DALI power supply (PSU)**.
- We recommend the **Control Freak® UBi DALI PSU**.
- DALI lines must be:
  - Addressed correctly
  - Grouped as needed
- The hardware variant determines the outputs:
  - `1D1X`: 1 DALI + 1 DMX
  - `2D`: Dual DALI
  - A **4-line model** is also available

---

## NAC Configuration (5500NAC)

To install and run the Lua scripting library on the CBUS NAC:

1. Open a web browser and enter the **IP address** of your NAC.
2. Click on the **Configurator**.
3. Navigate to:  
   `Scripting → Tools → Restore Scripts`
4. Upload and restore the provided **eDIDIO scripting library**.

---

## Lua Functions

The library provides a variety of Lua functions to control DALI and DMX devices through the eDIDIO controller.

- **DMX functions** allow setting channel values and effects
- **DALI functions** include addressing, group control, scene control, and querying
- **Enumerations** are provided to simplify writing commands

> For a full list of functions and enums, refer to the included PDF.

---

## License

This library is provided under license by **Control Freak®**. Unauthorized distribution or modification is prohibited.
