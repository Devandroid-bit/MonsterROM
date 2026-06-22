# MonsterROM Live Fixes for t2s

This regular KernelSU module carries the current MonsterROM t2s live payload:

- Patched `/system/etc/libnfc-nci.conf` from the generated t2s target.
- Patched `/system/etc/vintf/compatibility_matrix*.xml` files from the generated
  t2s target.
- Runtime property guards for UFFD GC, remote key provisioning, Bluetooth
  offload, the Vulkan renderer toggle, and SurfaceFlinger shader-cache priming.
- Patched `/system/cameradata/camera-feature.xml` with the incompatible
  video-beauty paths disabled.
- Patched Bluetooth APEX payload:
  - `/apex/com.android.bt/app/Bluetooth@CP2A.260605.016/Bluetooth.apk`
  - `/apex/com.android.bt/javalib/framework-bluetooth.jar`
  - `/system/apex/com.android.bt.apex`

The Bluetooth payload forces the framework-side A2DP offload flags off, including
`A2dpService.mA2dpOffloadEnabled`, `AdapterProperties.isA2dpOffloadEnabled()`,
and `Flags.a2dpSinkOffload()`.

Install `meta-erofs-binder` first, reboot, then install this module and reboot.

This module cannot fix early init files such as `ueventd.rc`, because KernelSU
module scripts and metamodule mounts run after the earliest init stages.
