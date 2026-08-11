# 05 — Privileged Services

## The ps_* daemons

Four root D-Bus services wrap privileged syscalls. They are Samsung dev-tool
helpers, present on the system bus:

| Name | Wraps |
|------|-------|
| `com.safe.ps_mount` | `/bin/mount` |
| `com.safe.ps_umount` | `/bin/umount` |
| `com.safe.ps_insmod` | `/sbin/insmod` |
| `com.safe.ps_mknod` | `/bin/mknod` |

Binaries live under `/usr/apps/privileged-service/bin/ps_*`, systemd units
`Type=dbus`, bus names `com.safe.ps_*`.

All calls go through `PS_Executor::Execute` → caller-auth
(`PS_Auth::GetCallerPid`): the **executable path** of the calling process and,
for ps_mount, the command line, must match a whitelist credential loaded from
**XML config** at daemon startup.

## Credential model

Each credential = (SMACK-label-regex, exe-path, command-regex-vector for
ps_mount only).

**The SMACK label is a REGEX, not a pinned label.** Most rules use
`[A-Za-z0-9_.:-]+` — the real gate is the **caller exe path** (+ mount cmd
regex for ps_mount). The widget cannot change its own exe path, so it cannot
impersonate a whitelisted caller. The attack model is: **drive a whitelisted
daemon** into calling ps_* with attacker-influenced arguments.

### Notable ps_mount rules (from firmware RE)

- `/usr/bin/appbinary-manager` → loop mounts under `appbinarymanager/emps/`
- `/usr/bin/canalysis-daemon` → `empCanalysis.img` temp mount
- `/usr/bin/wgt-backend`, `webappservice`, `node`, `xwalk_runtime`, … →
  `.tmg` / `.img` loop mounts into app paths or `/tmp`

## Live auth gate (2026-08-09) — CLOSED

On the live UN55MU6290 (FW 1410):

- Credential XML (`PS_AuthInfo`, `MatchAuth`, …) is **not present anywhere**
  on device or in the extracted rootfs image searched.
- Daemons log startup `configinfo v1.0 <md5>` but load **zero rules**.
- Every widget `CallCommand` → constant **`(7, 0)`** = `RULE_NO_FOUND` (no
  matching credential), regardless of command string.
- **`canalysis-daemon` was not running** in the live process list during this
  audit; even if started, it would still need loaded credentials to pass ps_*
  auth.

**Implication:** the theoretical chain “unsigned kernel module + ps_insmod”
is blocked at the daemon, not at module signing. Kernel module signing is
**OFF** (unsigned `.ko` would load if `insmod` were invoked as root), but
ps_insmod never reaches `/sbin/insmod` without XML credentials — installing
which is itself a root problem.

To reopen this vector would require **writing** the credential XML where the
daemon loads it (unknown runtime path; not embedded in binary) or **offline
firmware patch**.

## appbinary-manager (ABM) dispatch

`appbinary-manager` (root) is reachable by the widget over D-Bus and is one of
the intended callers of ps_mount **when credentials exist**.

- `AppBinaryManagerExecudeSync(ssss)` is a **stub**: only
  `GetAppBinaryVersion`; Mount returns empty.
- Real dispatcher: **`AppBinaryManagerExecudeAsync(iiissss)`** →
  `CMountService::Mount` → ps_mount.

### Mount round-trip (verified, pre–auth-gate audit)

Driving ABM async Mount loop-mounted a test squashfs **as root** into the emps
tree. This proved ps_mount + ABM wiring works when auth passes.

### Exec from the mount: falsified

Payload inside the RO mount → `rc=126 Operation not permitted`. UEP is
**per-file/inode**, not mount-writability-keyed. RO-loop-mount exec bypass is
dead.

The mount primitive (when auth works) only places owner content in root-owned
trees — useful for testing UEP, not for running unsigned code.

## ps_insmod / ps_mknod (design vs live)

Design: **no command-path regex** — `/sbin/insmod` / `/bin/mknod` receive
caller-supplied arguments; only caller-exe whitelist matters.

Live FW 1410: whitelist never loads → **no caller passes**, including
appbinary-manager, canalysis-daemon, wgt-backend, etc.
