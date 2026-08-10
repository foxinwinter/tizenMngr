# 11 — System Bus Surface (2026-08-09 sweep)

Live and firmware analysis of what the uid-5001 widget can **reach** on the
system bus versus what actually **escalates**. Complements
[03 — D-Bus Security](03-dbus-security.md) and
[10 — Status & Plan](10-status.md).

## Default policy is permissive

`/usr/share/dbus-1/system.conf` `<policy context="default">` allows
`send_type="method_call"` (and signals/replies) with **no destination
restriction**. Any service without its own `/etc/dbus-1/system.d/*.conf`
(only ~27 conf files exist) is callable at the **bus layer**. Enforcement
happens inside each daemon (SMACK, `<check>` privileges, polkit, custom auth).

Confirmed: widget → `org.freedesktop.systemd1` (`ListUnits`/`GetUnit` work);
widget → `com.safe.ps_insmod` (returns auth failure, not bus reject).

## privileged-service (`com.safe.ps_*`)

Four root daemons: `ps_insmod`, `ps_mount`, `ps_umount`, `ps_mknod`.
API: `<iface>.CallCommand(command:s, data:i)` at `/com/safe/<svc>`.

Auth model (reversed from binaries + live behavior):

- XML-driven `PS_AuthInfo` / `PS_Rule` / `MatchAuth` credential list.
- Caller identity from kdbus sender PID → `/proc/<pid>/exe` + SMACK label.
- On auth failure the daemon returns constant **`(7, 0)`** — error code 7 =
  `RULE_NO_FOUND` (no matching credential).

**Live verdict:** credential XML is **absent device-wide** (grep across
rootfs paths + extracted firmware: zero hits). Daemons start with
`configinfo v1.0 <md5>` but **zero rules loaded** → every caller rejected,
including would-be whitelisted agents like `canalysis-daemon`. Kernel module
signing is OFF (`/sbin/insmod` would load unsigned `.ko`), but the ps_*
gate never opens without that XML (which would itself require root to install).

See [07 — Privileged Services](07-privileged-services.md).

## org.tizen.pkgmgr

`org.tizen.pkgmgr.conf` gates admin methods with
`http://tizen.org/privilege/packagemanager.admin` via dbus `<check>`.

Live probes from the widget:

| Method | Result |
|--------|--------|
| `check`, `getsize_sync` (`.info` privilege) | Allowed (public privilege) |
| `clearcache`, `kill`, `uninstall` (`.admin`) | Rejected — XML security policy |

`security-manager` / `cynara` units are stub `echo` services on this firmware,
but **privilege checks still work** — they do not fail open.

## org.freedesktop.systemd1

Policy allows many control methods, but systemd enforces its own check:
`StartTransientUnit` → `AccessDenied`. Information methods (unit list, dump,
subscribe) work — full inventory, no control.

## org.tizen.system.deviced (root)

Policy: `<allow send_destination>` with **no privilege check** for most
interfaces. Deep-dive (offline binary + live):

- Only **Tzip mount/unmount** is app-gated (`is_app_privileged` + exact SMACK
  label match). Widget fails this gate.
- **Power, display, key, process** interfaces are ungated.
- Live: `PowerOff` / reboot from widget **confirmed** → TV power-cycle (DoS).
- Process interface can read `/proc/<pid>/…` for many PIDs — disclosure, not
  write/exec.

## org.tizen.tv.factory-service (root)

**Ungated** factory NVRAM / config API on `/TIFacSerObj`:

- `SetParameter`, `GetUidItem`, `GetItem`, `SetHotelModeInfo`, `Executes`, …
- Persistent across reboot; demonstrated for white-balance recovery and
  (accidentally) config corruption — see [fixes/tint-fix.md](fixes/tint-fix.md).
- No arbitrary code execution; can brick-by-config or flip feature flags.

## org.tizen.tv.automation-service

`/TIFacAutoObj` — `ExecuteCommand(i,i)` reachable. Factory automation /
RS-232 path. **Probing has real hardware side effects** (panel WB corruption
observed historically). Treat as reachable factory control, not a clean LPE.

## com.samsung.* MethodCall RPC

T-DIS-style `MethodCall(functionCode, inDataBuffer)` on multiple
`com.samsung.*` services. `Ping` / introspection succeed; actual `MethodCall`
→ **`EPIPE` (kdbus: Broken pipe)** and the service name drops briefly —
dispatcher validates sender and kills disallowed connections. **Closed to
widget.**

## Other notes from the sweep

| Surface | Verdict |
|---------|---------|
| `org.volt.vrtinstaller` | Root; downloads signed panels from Samsung servers — trust/MITM gated |
| `/dev/iotnode` (chmod 777 @ boot) | Mode/PID flag for IoT framework, not exec |
| SWU / OTA daemons | Signed update packages (UEP); not bypassable without keys |
| `services-fw` control file | Under `/opt/usr/apps` — not widget-writable |
| zone-manager (LXC) | Root TCP listener; SMACK blocks widget connect |
| World-writable `/dev` nodes | `kfactory`, `i2c-*`, `fuse`, etc. — see [08 — SUID & Daemons](08-suid-daemons.md) |

## Writable footprint (widget)

Confirmed creatable paths: `/tmp`, `/var/tmp`, `/dev/shm`, widget app tree
under `/opt/usr/home/owner/apps_rw/<app>/`, and owner home subtrees. **Not**
writable: `/etc`, `/var`, `/opt` (except owner paths), `/usr`, `/mnt`. No
world-writable regular files on the system. Root daemons use `/tmp` for flags
and configs, not for executing widget-dropped binaries.

## Overall

Bus **reachability** is wide; **escalation** requires passing per-service gates.
After this sweep, confirmed unprivileged impact without root is **power-cycle
DoS** + **factory NVRAM tampering** + CVE-family side effects (WM/audio/etc.).
Module load, mount-as-root via ps_*, package admin, and systemd control remain
closed from the sandbox.
