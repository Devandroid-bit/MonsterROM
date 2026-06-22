# EROFS Bind Mount Metamodule

This is a KernelSU Next / KernelSU metamodule for EROFS ROM ports where regular
module file payloads need to be bind-mounted instead of written into read-only
partitions.

Install this module first, reboot, then install regular payload modules such as
`monsterrom-livefix-t2s`. KernelSU only allows one active metamodule at a time,
so remove other metamodules before using this one.

Behavior:

- Honors regular module `disable`, `remove`, and `skip_mount` flags.
- Scans enabled modules under `/data/adb/modules`.
- Bind-mounts individual existing files from supported partition folders:
  `system`, `system_ext`, `product`, `vendor`, `odm`, `system_dlkm`,
  `vendor_dlkm`, `odm_dlkm`, and `oem`.
- Uses `mount -o bind,dev=KSU` first so KernelSU can identify the mount source.
- Skips missing targets instead of creating paths on EROFS partitions.

This deliberately does not mount whole partition directories. That keeps a small
livefix payload from hiding files that are not part of the module.
