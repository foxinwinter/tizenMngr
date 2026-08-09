# 07 — Privileged Services

## The ps_* daemons

Four root D-Bus services wrap privileged syscalls. They are Samsung dev-tool
helpers, present on the system bus:

| Name | Wraps |
|------|-------|
| `com.safe.ps_mount` | `/bin/mount` |
| `com.safe.ps_umount` | `/bin/umount` |
| `com.safe.ps_insmod` | `/sbin/insmod` |
| `com.safe.ps_mknod` | `/bin/mknod` |

All calls are gated by `PS_Executor::Execute` → caller-auth
(`PS_Auth::GetCallerPid`): the **executable path** of the calling process and,
for ps_mount, the command line, must match a whitelist credential.

## Credential model (ps_mount)

The rules are built in code by `PS_CredentialManager::GetCredentials()`.
Each credential = (SMACK-label-regex, exe-path, command-regex-vector).

**KEY INSIGHT: the SMACK label is a REGEX, not a pinned label.** Most rules use
`[A-Za-z0-9_.:-]+` (ANY label) — the real gate is the **exe path** of the
caller + the mount command line. The widget cannot change its own exe path, so
it cannot impersonate a whitelisted caller. The only attack is to **drive a
whitelisted daemon** into making the mount/insmod/mknod call with
attacker-influenced arguments.

### Notable ps_mount rules

- `/usr/bin/appbinary-manager` →
  `mount -o ro,loop,nodev,nosuid /opt/usr/apps/appbinarymanager/emps/emp<X>_img/emp<X>.img → (pepper | emps/emp<X> | pepper/<X>)`
- `/usr/bin/canalysis-daemon` →
  `mount -o loop /opt/usr/apps/appbinarymanager/empCanalysis.img .../temp_mount`
- `/usr/bin/wgt-backend` (several) → `mount -o loop,nosuid .../temp/<n>_tmg/<f>.tmg` to `apps_rw/<app>` or `/tmp/<n>`
- `/usr/apps/org.tizen.webappservice/bin/webappservice` (several) → icon
  `.img` loop mounts
- `/usr/bin/node`, `/usr/bin/xwalk_runtime` → `apps_rw/<app>/res/*.tmg` mounts
- `/usr/bin/contents-recognition-service`, `vddebugmenu` (System label),
  `waapp-swupgrade`, netflix-app, `ignitionLaunch`/`launchpad-loader`

## appbinary-manager (ABM) dispatch

`appbinary-manager` (root) is reachable by the widget over D-Bus and is one of
the SMACK-authorized callers of ps_mount.

- `AppBinaryManagerExecudeSync(ssss)` is a **stub**: it only handles
  `strCmd == "GetAppBinaryVersion"`; anything else (including Mount) returns an
  empty string and does nothing.
- The real generic dispatcher is **`AppBinaryManagerExecudeAsync`** with
  signature `(iiissss)` =
  `requestID, pid, signalSubscribeID, strCmd, strName, strParam1, strParam2`
  → spawns `AsyncHandleFunc` → `ProcessEvent` → `CMountService::Mount`.

### Mount round-trip (verified)

A test squashfs image was loop-mounted **as root** by driving ABM's async
dispatcher to call ps_mount:

```
AppBinaryManagerExecudeAsync 1 123 456 'Mount' \
  '/opt/usr/apps/appbinarymanager/emps/empTT_img/empTT.img' \
  '/opt/usr/apps/appbinarymanager/emps/empTT' ''
→ creates /opt/usr/apps/appbinarymanager/emps/empTT (drwx------)
→ /dev/loopN mounted (squashfs, ro,nosuid,nodev,relatime,loop)
```

So the mount primitive works end-to-end from the unprivileged widget: **root
authorizes loop-mounting arbitrary owner content** into the emps tree.

### Exec from the mount: falsified

Executing a payload inside the RO mount:
`/opt/usr/apps/appbinarymanager/emps/empTT/x.bin` → `rc=126 Operation not
permitted`. The payload never ran.

**Conclusion**: UEP is per-file/inode enforcement, NOT mount-writability-keyed.
The RO-loop-mount exec bypass hypothesis is dead. The mount primitive remains
useful only for placing root-readable content in root-owned trees (and
verifying UEP semantics).

## ps_insmod / ps_mknod

Unlike ps_mount, these have **no command-path regex** — they call
`/sbin/insmod` / `/bin/mknod` as root with whatever arguments arrive, gated
only by the caller-exe whitelist.

Open question (active): which caller executables are whitelisted for these two
services, and whether any of them is reachable from the owner context with
attacker-influenced arguments (e.g. via canalysis-daemon, an authorized
caller, or another root daemon driven over D-Bus). If insmod's module path is
not regex-gated, the remaining question is kernel module signing
requirements for `.ko` files.
