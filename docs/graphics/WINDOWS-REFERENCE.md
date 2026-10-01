# Windows Intel graphics driver reference

This document records facts extracted from Lenovo's original BayTrail-T
driver packages. The Windows binaries are reference material only; they are
not candidates for direct loading or recompilation on Linux.

## Packages inspected

Two Lenovo Inno Setup packages were preserved under ignored `debug/` data:

- Windows 10 package `2nf8029f.exe`.
- Windows 8.1 package `fabd17ww.exe`.

The graphics INF in both packages is `Drivers/GFX/igdlh.inf`.

The INF driver versions are:

- Windows 10 package: `10.18.10.4242`, dated 2015-06-16.
- Windows 8.1 package: `10.18.10.3348`, dated 2013-10-31.

## Hardware matching

Both Intel INFs match the tablet GPU generically by PCI device ID:

```text
PCI\VEN_8086&DEV_0F31
```

The device description is `Intel(R) HD Graphics`.

No Lenovo subsystem match such as `SUBSYS_390117AA` is used by the graphics
INF. This is important: the Windows graphics package is also a generic
Valleyview driver, while board/panel-specific behaviour is supplied by
firmware/configuration rather than a separate Miix GPU implementation.

## Windows driver architecture visible in the package

The package contains distinct Windows components, including:

- `igdkmd32.sys` — kernel-mode graphics driver;
- `igdumdim32.dll` / `igd10iumd32.dll` — user-mode Direct3D components;
- `ig75icd32.dll` / `ig7icd32.dll` — OpenGL ICDs;
- Media SDK / `libmfxhw32.dll` components;
- OpenCL libraries;
- control-panel and display-management applications.

This reinforces that the old Windows package is a WDDM driver stack, not a
single portable device module.

## Valleyview registry policy

The 2015 INF applies Valleyview-specific policy such as:

```text
Display1_DisableAsyncFlips = 1
ScalerToHDMI_Enable        = 0
DisplayOptimizations       = 0x19
AvoidPPSOutsideModeSet     = 1
```

The INF comments describe `DisplayOptimizations` as including fast-mode-set,
T3 optimisation, and power-off optimisation. These Windows registry names do
not map one-to-one to i915 module parameters, so they must not be copied
blindly.

They are useful clues when investigating a matching symptom. For example,
`AvoidPPSOutsideModeSet` makes panel power sequencing worth comparing if the
Miix later shows a suspend/resume or blanking failure.

## What to reuse from Windows

Useful reference data:

- exact PCI IDs and supported OS/device sections;
- driver-version history;
- generic Valleyview policy and workarounds;
- display timing or firmware behaviour observed while Windows is installed;
- VBT/ACPI state and register traces where legally and technically practical.

Do not attempt to translate the Windows DLL/SYS binaries into a Linux module.
Linux already has the native i915 kernel driver and Mesa Crocus userspace for
this hardware. The productive task is to compare behaviour and implement the
smallest missing Linux fix.
