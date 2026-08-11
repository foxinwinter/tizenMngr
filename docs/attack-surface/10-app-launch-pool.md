# 10 — App Launch Pool (native-exec unlock analysis)

Status: **investigated, largely falsified live (2026-08-10).** Documented here as
the record of the `launchpad-process-pool` deep-dive and the leads it leaves
open. Nothing in this file is a working escalation.

## What it is

`launchpad-process-pool` (Samsung `app_launcher` core) is the daemon that
forks/execs app processes on launch. On this TV it runs as **uid 5001**
(not uid 200 — see falsification below) with SMACK label `System::Privileged`,
and it is the **direct parent** of our widget process.

- Unix socket dir: `/run/aul/daemons/5001/` (mode 777, owned by uid 5001)
- Listen socket: `.launchpad-process-pool-sock`
- Sibling sockets: `.launchpad-type0-0` .. `.launchpad-type3-0`, `.amd-sock`
- `main` calls `sd_listen_fds` (systemd socket activation) before binding;
  on TV the fd may come from systemd.

The pool was the only known place where a client-supplied string
(`__AUL_LOADER_PATH__`) gets `execv`'d by a higher-privilege daemon — i.e. a
potential **native-exec unlock** past the SFD-UEP wall
([Execution Model](../platform/03-execution-model.md)).

## Wire format (type-11 LAUNCH)

- **Header (12 bytes):** `[u32 type][u32 payload_size][u32 src(echoed)]`.
- **Payload:** base64( 32-byte **lowercase-hex MD5 of the entry blob** + entry blob ).
  The MD5 covers everything after byte 32; the 32 header bytes are otherwise ignored.
- **Entries:** `[u32 entry_size][u32 flags][u32 key_len][key][u32 val_len][val]`,
  `entry_size = 16 + key_len + val_len` (flags bit31 = array type). `key_len`/`val_len`
  include the trailing NUL; the key string is read via `strdup`.
- Client keys: `__AUL_LOADER_PATH__` (exec'd **unvalidated**),
  `__AUL_LOADER_EXTRA__`, `__AUL_LOADER_ID__`, `__AUL_CALLER_PID__`,
  `__AUL_SDK__`, `__AUL_PRIVACY_APPID__`.

## Peer-credential gate — CONFIRMED

After `accept()`, if the peer `uid > 4999` the pool calls
`__check_caller_by_pid(peer_pid)` **before** decoding the bundle
(`0x1321c`, called from `0x14960`). It reads `/proc/<pid>/attr/current`
(SMACK label) and requires it to be **exactly one of
`{User, System, System::Privileged}`**; otherwise it closes the socket and
drops the packet. Uids ≤ 4999 (system daemons) skip the check entirely.

- Peer creds come from `getsockopt(SO_PEERCRED)` — kernel-supplied, unforgeable.
- Our widget (`User::Pkg::kdbuswgt01`, uid 5001 > 4999) is **rejected**.
- A bundle-level caller check exists but is only reached after the gate:
  omit `__AUL_SDK__` (bundle type → -1, check skipped) or set
  `__AUL_CALLER_PID__ = "0"` (strtol ≤ 0 skips). It is the same
  `__check_caller_by_pid` on a bundle-supplied pid.
- **No file on the device carries a whitelisted label**, and files cannot be
  relabeled (`chsmack -a/-e` → kernel EPERM) → exec-transmute to a whitelisted
  label is impossible.

## Type-11 slot + idle-timer exec chain — CONFIRMED

A type-11 LAUNCH creates the slot on the fly (no pre-existing slot needed):
counter++ → `__find_slot` → on NULL `__add_slot(id=100, counter,
strtol(__AUL_CALLER_PID__), __AUL_LOADER_PATH__, __AUL_LOADER_EXTRA__, ...)`.
Requires `__AUL_LOADER_PATH__` **and** `__AUL_CALLER_PID__` non-null;
`__AUL_LOADER_EXTRA__` optional.

Then `__set_timer(slot)` → `g_timeout_add(1000ms, __handle_idle_checker, slot)`;
when CPU idle ratio > 89 it calls `__prepare_candidate_process` → builds argv
`{loader_path, 1024-byte buf, path-string, extra}` →
`__fork_app_process(__exec_loader_process, argv)` → `fork()`; child `execv`s
our `loader_path`.

**"DIRECTLY" mode** (`__AUL_LOADER_ID__` = svcapp/widgetapp/webapp) forks
`__exec_app_process`, whose exec path comes from the read-only DB via
`_launcher_info_get_exe` — **not controllable**.

## Falsified live: the "uid 200 / system" premise

The offline disassembly (an older pool build) showed the pool init sequence:
`setreuid/setregid(TZ_SYS_UID, TZ_SYS_GID)` with `TZ_SYS_UID = system = uid 200`,
plus a caps dance (`CAP_DAC_OVERRIDE`, `CAP_SYS_PTRACE`, etc.).

**Live (2026-08-10):** the pool runs as **uid 5001**, not 200 —
`/run/aul/daemons/5001/` is the only daemon dir, and the pool's direct child
(the widget) is **uid 5001, CapEff=0, label `User::Pkg::kdbuswgt01`**. So pool
fork/exec children gain **no new uid and no new caps** over the widget we
already have. The only conceivable remaining win from a successful LAUNCH is an
inherited `System::Privileged` SMACK label if the pool does not relabel the
loader child.

## Open leads (on hold)

1. **litewebappservice — gate-passing sender.** It requested our widget's launch
   and **passed the gate**, so it must hold a whitelisted SMACK label at uid 5001.
   It exposes a user-bus D-Bus interface `org.tizen.tv.litewebappservice.server.interface`
   with `launch_app(obj_name s, thread_id i, app_id s, payload s, callerid s, ...)`
   (`payload` is a caller string; it flows into `app_control_send_launch_request`
   / `app_control_add_extra_data` in libaul). **Open question:** does that payload
   (or the app_control it builds) reach the pool bundle and let us inject
   `__AUL_LOADER_PATH__` with gate-passing creds?
   - Unit: `org.tizen.litewebappservice.service`, Type=dbus,
     BusName=`org.tizen.tv.litewebappservice.server`, User=owner, Group=users,
     ExecStart=`/usr/bin/app_launcher -f org.tizen.litewebappservice`, `AllowWorld=talk`.
   - Firmware binary: `/usr/apps/org.tizen.litewebappservice/bin/litewebappservice`
     (ELF32 ARM, stripped; full disasm in working notes).
2. **Socket replacement / MITM.** We own `/run/aul/daemons/5001/` (777).
   Replacing the pool socket would only capture traffic *to* the pool — but the
   pool's peer gate would then see the *replacing process'* creds, so this alone
   does not bypass the gate; it is listed for completeness.
3. **Does a LAUNCH loader child keep `System::Privileged`?** Only testable with a
   gate-passing sender (lead 1).

## Status summary

| Claim | Verdict |
|-------|---------|
| Pool execs client-supplied `__AUL_LOADER_PATH__` | CONFIRMED (disasm + child parentage) |
| Gate = SMACK whitelist `{User, System, System::Privileged}` via SO_PEERCRED | CONFIRMED |
| Widget can pass the gate | **NO** (`User::Pkg::kdbuswgt01` rejected) |
| Pool drops to uid 200 (system) → sandbox escape | **FALSIFIED live** — pool is uid 5001 |
| LAUNCH children gain uid/caps | **NO** — uid 5001, CapEff=0 |
| litewebappservice can be used as gate-passing launcher | **OPEN** — untested |

See [Status & Plan](../status/11-status.md) for how this fits the overall
research picture.
