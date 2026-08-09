# 10 — Status & Plan

## Status

| Area | Status | Verdict |
|------|--------|---------|
| Dev-mode foothold | DONE | sdb fixed command set; no shell, no root |
| CVE-2014-1303 (WebKit) | DONE | DEAD — engine is Chromium 47, bug N/A |
| CVE-2018-16262..16268 (D-Bus) | DONE | 16262 patched; 16266/16268 vulnerable pattern confirmed; SMACK caveat |
| D-Bus transport | DONE | kdbus REACHED via signed tools (milestone) |
| SFD-UEP exec blocker | DONE | root-caused; no exec from writable mounts without Samsung key |
| Kernel CVE assessment | DONE | 5195/8655/0728 in range, all gated on exec wall |
| JIT shellcode primitive | DONE | syscall whitelist blocks kernel-exploit syscalls → dead end |
| ps_* credential model | DONE | caller-exe whitelist is the gate |
| appbinary-manager mount | DONE | mount round-trip works; exec from RO mount falsified (UEP per-file) |
| wasutility (SUID) | DONE | DEAD END (no attacker-controlled exec/write) |
| kfactoryd | DONE | live R/W channel; ramdump path dead |
| rmdemon | DONE | cloud client, not LAN listener |
| ps_insmod/ps_mknod caller-auth | ACTIVE | no path regex; find whitelisted callers |
| canalysis-daemon call_app | PENDING | SMACK-authorized ps_* caller; trigger test |

## Active / next steps

1. **ps_insmod/ps_mknod caller-auth** — identify whitelisted caller
   executables; check whether any is reachable from the owner context with
   attacker-influenced args; determine kernel module signing requirements.
2. **canalysis-daemon `call_app`** trigger test — it is a SMACK-authorized
   `ps_mount`/`ps_insmod`/`ps_mknod` caller running as root.
3. Fallback: drive a whitelisted `wgt-backend`/`webappservice` into an allowed
   loop-mount with attacker-controlled `.tmg`/`.img` content (readable
   root-owned tree at the mount target).

## What was ruled out

- WebKit CSS UAF (CVE-2014-1303) — engine is Chromium 47, not WebKit.
- RO-loop-mount exec bypass — UEP is per-file, not mount-writability-keyed.
- JIT shellcode → kernel exploits — fixed syscall whitelist + blocked
  JIT→libc transfer.
- GhostLock (futex-PI + keyring UAF) — keyring syscalls blocked.
- wasutility SUID — no controllable exec/write.
- kfactoryd ramdump/exec_shell — missing `kexec_crash_loaded`.
- rmdemon — outbound cloud client, pincode-gated.
- pkgmgr D-Bus (CVE-2018-16262) — patched in this firmware.
