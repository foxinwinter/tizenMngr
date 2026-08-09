# 08 — SUID & Daemons

## SUID audit

Only three SUID binaries on the live TV:

| Binary | Notes |
|--------|-------|
| `/usr/bin/wasutility` | root SUID — see below |
| `/usr/lib/chromium-efl/chrome-sandbox` | Chromium sandbox helper |
| `/usr/lib/dbus/dbus-daemon-launch-helper` | group `dbus` only (not our gid) |

## wasutility (SUID root) — dead end

`/usr/bin/wasutility` = `-rwsr-xr-x root root`, exec-able from the widget.
Identity: **AppRecoveryTool** (`org.tizen.webappservice-0.1`,
`src/Tool/AppRecoveryTool.cpp`). Full disassembly; all option handlers are
**fixed-argument**:

- Most cases `exec` a **missing** binary (`wrt-installer` absent from FW) with
  a hardcoded `PATH=` env — dead.
- `-r` runs `/usr/bin/pkgcmd --clear-all -t wgt` — exists, but fixed args only.
- `-a`/`-d` use a TMGSettings D-Bus client — fails live
  (`PkgMgr Client Creation Failed`, SMACK-gated).
- `-n` execs fixed-argv `/bin/chown`/`/bin/chsmack` on
  `.webappservice.db[-journal]`; the SQL source (`AppsDB.conf`) lives in a
  SMACK-protected dir — not attacker-controllable.
- `-m` reads `/proc/<pid>/vd_memstat` (Samsung proc file) — root read only.

The exec launcher uses `execve` (no shell), so no argument injection. Verdict:
**no attacker-controlled root exec, no controllable file write.**

## kfactoryd — root daemon, live R/W channel

- `/usr/bin/kfactoryd` (root) + world-writable `/dev/kfactory`
  (char 244,0, mode 0666). **20-byte packet protocol, live R/W to a root
  daemon confirmed.**
- Commands: `0x1234` GetData, `0x4321` sysinfo, `0xabcd` SetData.
- The promising `exec_shell`/`write_vmcoreinfo` path (`echo ... >
  /sys/kernel/vmcoreinfo` via `/bin/sh -c` from `/etc/prd_info.ini`) is **gated
  by `/sys/kernel/kexec_crash_loaded`, which does NOT exist on the live TV** →
  ramdump_init bails. Not exploitable.
- `main`'s `system()` only runs a fixed `oom_score_adj` echo — not
  attacker-controlled.
- Open: what consumes `SetData(0xabcd)` (libfactory-interface.so not yet
  reversed); sysinfo may leak build/version.

## rmdemon — cloud client, not a LAN listener

`/usr/bin/rmdemon` (org.tizen.remote-management v0.2):
- **Outbound HTTPS client** to Samsung's RM cloud
  (`https://rm.samsungqbe.com`), protocol v2.5, pincode-authenticated.
- No `bind`/`accept`/`listen` strings → no local TCP listener. The "network
  root daemon" hypothesis was wrong.
- Server-initiated commands (file write, packet dump, 100 MB temp cap) run as
  root but require: RM feature enabled + MITM of the cloud domain + HTTPS
  cert trust + completing the pincode flow. **Not unauthenticated.**

## D-Bus root daemons

- `org.tizen.tv.contentsanalysis.server` = **canalysis-daemon**, one of the
  two SMACK-authorized callers of `ps_mount`/`ps_insmod`/`ps_mknod`. Object
  `/org/tizen/tv/contentsanalysis`, iface `org.tizen.tv.contentsanalysis`
  with `call_app(command:i,param1:t,param2:i,param3:s,reminder:u)`,
  `get_handle`, `set_hp_status`, etc. Runs as root. **Active research target.**
- deviced, comss.server, contentsanalysis run as root; their `/proc` entries
  are SMACK-hidden (empty status/cmdline). No methods found via introspection
  of deviced.
- `org.tizen.tv.factory-service` — NVRAM read/write (see
  [09 — Tooling](09-tools.md) → NVRAM section).
