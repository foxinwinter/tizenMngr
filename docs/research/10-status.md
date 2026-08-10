# 10 — Status & Plan

Last major update: **2026-08-09** (live system-bus sweep + ps_* auth gate audit).

## Status

| Area | Status | Verdict |
|------|--------|---------|
| Dev-mode foothold | DONE | sdb fixed command set; no shell, no root |
| Owner-level exec | DONE | Widget service + signed `/usr/bin/node` (uid 5001) |
| CVE-2014-1303 (WebKit) | DONE | DEAD — engine is Chromium 47, bug N/A |
| CVE-2018-16262..16268 (D-Bus) | DONE | 16262 patched; 16266/16268 confirmed; no obvious root chain |
| D-Bus transport | DONE | kdbus reached via signed `dbus-send`/`busctl` |
| kdbus kernel bugs | DONE | DEAD — Samsung fork reply lifetime audited; no UAF/race |
| SFD-UEP exec blocker | DONE | per-file signing; no exec from writable zones |
| Kernel CVE assessment | DONE | 5195/8655/0728 in range, all gated on exec wall |
| JIT shellcode primitive | DONE | syscall whitelist + blocked JIT→libc |
| ps_* credential model | DONE | XML whitelist + PID/exe/SMACK match |
| ps_* live auth gate | DONE | **DEAD** — no credential config loaded; all callers get `7 0` |
| appbinary-manager mount | DONE | root loop-mount works; exec from mount falsified (UEP) |
| wasutility (SUID) | DONE | DEAD — no attacker-controlled exec/write |
| kfactoryd / `/dev/kfactory` | DONE | factory-register channel only; not arbitrary kernel memory |
| rmdemon | DONE | outbound cloud client, pincode-gated |
| canalysis-daemon → ps_* | DONE | **DEAD** — not running on live TV; ps_* gate closed anyway |
| pkgmgr admin via D-Bus | DONE | `<check>` enforcement works (negative live test) |
| deviced (root D-Bus) | DONE | ungated reboot/power-off = **DoS only**, no LPE |
| factory-service NVRAM | DONE | ungated read/write (config tampering, demonstrated) |
| com.samsung MethodCall RPC | DONE | connection killed (`EPIPE`) on disallowed senders |
| systemd1 control | DONE | `StartTransientUnit` etc. → AccessDenied |
| Root executes widget-writable file | DONE | **NONE** found (firmware + live hunt) |
| TIFSDaemon command surface | DONE | all shell invocations hardcoded literals |

## Confirmed widget impact (no root)

From uid 5001 / sandboxed widget context, verified **without** root:

- **TV reboot / power-off** via `org.tizen.system.deviced` power interface
  (ungated; live DoS demonstrated).
- **Persistent factory NVRAM tampering** via `org.tizen.tv.factory-service`
  (`SetParameter`, hotel mode, etc.) — can corrupt panel config; recovery
  documented in [fixes/tint-fix.md](fixes/tint-fix.md).
- **Information disclosure**: D-Bus introspection, systemd unit inventory,
  Enlightenment WM control (CVE-2018-16266 class), low-impact audio/popup
  surfaces.

High-impact sinks (module load, mknod, package install, systemd unit start,
Samsung TV RPC) are gated at the service or SMACK layer. See
[11 — System Bus Surface](11-system-bus-surface.md).

## Active / next steps

Widget → root paths through D-Bus and signed native exec are **largely
exhausted** on FW 1410. Remaining research lanes:

1. **`/dev/i2c-*` ioctl surface** — world-open to uid 5001; kernel 4.1.10 +
   SoC drivers = classic driver-bug class (needs controlled fuzzing from owner
   context, no unsigned exec required to *open* the node).
2. **Unidentified root listener (port 15500)** — map to daemon/service offline;
   widget TCP connect SMACK-blocked, but identity informs firmware RE.
3. **Offline firmware patch / reflash** — inject ps_* credential XML, patch a
   root daemon, or ship a persistent root helper in extracted rootfs (see
   working-tree `patch-methods.md`, not in this repo).
4. **Enlightenment `wm.Test`** — root-context window/key effects; no escalation
   chain documented yet.
5. **Factory / engineer UI** — Advanced-menu auth tied to NVRAM SID 2105;
   map whether engineer mode exposes capabilities beyond NVRAM.

## What was ruled out

- WebKit CSS UAF (CVE-2014-1303) — Chromium 47, not WebKit.
- RO-loop-mount exec bypass — UEP is per-file/inode, not mount-writability.
- JIT → kernel exploits — fixed syscall whitelist + blocked JIT→libc.
- GhostLock (futex-PI + keyring UAF) — keyring syscalls blocked from JIT.
- kdbus sync-reply UAF/race — Samsung fork uses ref-under-lock protocol.
- wasutility SUID — no controllable exec/write.
- kfactoryd ramdump / arbitrary kernel write via `/dev/kfactory`.
- rmdemon — cloud client, not LAN listener.
- pkgmgr install/uninstall/kill (CVE-2018-16262 class) — `<check>` denies admin.
- ps_insmod/ps_mount/ps_mknod via widget or missing whitelisted caller — no
  credential XML on device → constant auth reject (`RULE_NO_FOUND` / `7 0`).
- Driving canalysis-daemon — absent from live process list during audit.
- Root executes a file the widget can write — hunt found none.
- TIFSDaemon — no attacker-controllable `system()` / shell path.
