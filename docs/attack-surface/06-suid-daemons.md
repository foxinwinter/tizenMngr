# 06 — SUID & Daemons

## SUID audit

Only three SUID binaries on the live TV:

| Binary | Notes |
|--------|-------|
| `/usr/bin/wasutility` | root SUID — see below |
| `/usr/lib/chromium-efl/chrome-sandbox` | Chromium sandbox helper |
| `/usr/lib/dbus/dbus-daemon-launch-helper` | group `dbus` only (not our gid) |

(Firmware rootfs sweep also reports no other setuid binaries in the image.)

## wasutility (SUID root) — dead end

`/usr/bin/wasutility` = `-rwsr-xr-x root root`, exec-able from the widget.
Identity: **AppRecoveryTool** (`org.tizen.webappservice-0.1`). Full
disassembly; all option handlers are **fixed-argument**:

- Most cases `exec` a **missing** binary (`wrt-installer` absent from FW).
- `-r` → fixed `pkgcmd --clear-all -t wgt`.
- `-a`/`-d` → TMGSettings D-Bus client fails live (SMACK-gated).
- `-n` → fixed `chown`/`chsmack` on webappservice DB paths; SQL source not
  attacker-controllable.
- `-m` → read `/proc/<pid>/vd_memstat` only.

`execve` only, no shell — **no attacker-controlled root exec or write.**

## kfactoryd — factory channel, not kernel memory

- `/usr/bin/kfactoryd` (root) + world-writable `/dev/kfactory` (char 244:0,
  mode 0666).
- 20-byte packet protocol; live open/read/write as uid 5001 confirmed.
- **2026-08-09 live test:** traffic is kernel-initiated read requests for
  **factory register addresses**; userland responds to matched requests. The
  kernel controls the address space — **not** an arbitrary kernel-memory write
  primitive. Prior “modprobe_path via kfactory” hypothesis **closed**.
- Ramdump / `exec_shell` path gated by missing `kexec_crash_loaded` on device.
- NVRAM-style access also available via factory-service D-Bus (preferred for
  research).

## rmdemon — cloud client, not a LAN listener

Outbound HTTPS to Samsung RM cloud; pincode-authenticated. No local listener.
Root actions require cloud trust + pincode — not unauthenticated LAN exploit.

## D-Bus root daemons (selected)

### canalysis-daemon — not a live vector here

`org.tizen.tv.contentsanalysis.server` — intended whitelisted caller for
ps_mount (and potentially ps_insmod/ps_mknod **if** credential XML were
loaded). **`call_app(...)`** and related methods exist in firmware.

Live audit: process **not present** in `ps` output; ps_* auth gate **closed**
(no credentials). Marked dead for this device/firmware snapshot.

### deviced — DoS, not LPE

`org.tizen.system.deviced` (root). Ungated power/reboot/display/key surfaces;
Tzip mount gated (widget fails SMACK check). Live reboot from widget
confirmed. See [System Bus Surface](09-system-bus-surface.md).

### org.tizen.tv.factory-service

Ungated NVRAM/config read-write (`SetParameter`, `GetUidItem`, …). Persistent
config tampering vector; no code exec. See [Access Channels & Tooling](../platform/02-access-tooling.md).

### TIFSDaemon

Factory-service binary audited: all `system()` / `ExecuteShell` paths use
**hardcoded command literals** only — no D-Bus-controlled shell strings.

## World-writable `/dev` nodes (uid 5001)

Openable from widget: `/dev/kfactory`, `/dev/i2c-0`…`i2c-9`, `/dev/fuse`,
`/dev/eeprom`, `/dev/sdp_mem`, `/dev/bptime`, log devices, etc.

- **kfactory** — factory data only (above).
- **i2c-*** — remaining live candidate for driver ioctl bugs (kernel 4.1.10);
  no exec required to open the node.
- **sdp_mem / bptime** — ioctl/mmap allocators, not `/dev/mem`-style arbitrary
  access.
