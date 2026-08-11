# tizenMngr

**tizenMngr is a Tizen TV management app** (TizenBrew module management, full
root app management/installation, and a kernel/root-exploit runner) for
Samsung Tizen smart TVs. Development is **on hold until full, repeatable root
access** is achieved — see [roadmap.md](roadmap.md).

This repository currently holds the **public documentation** for the security
research that is the prerequisite for the app: findings, analysis, and
methodology only. No exploit code, no live-network specifics, no credentials.

All work was performed on the owner's own device for research purposes.
Tizen 3.0 is EOL (2017); no further firmware patches exist.

## Help wanted: privilege escalation / root

We have a stable **uid-5001** owner-context foothold (widget service command
exec + signed `/usr/bin/node` + kdbus D-Bus), but **root (uid 0) is not
achieved** on FW 1410. The obvious lanes are largely exhausted and documented.
If you work on Samsung TV / Tizen exploitation, kernel 4.1.10, SMACK/kdbus, or
embedded device research, we'd value help on:

1. **Gate-passing launcher** — the app launch pool only accepts callers whose
   SMACK label is exactly `User`, `System`, or `System::Privileged` (peer creds
   via `SO_PEERCRED`, uid > 4999 must match). We found one gate-passing caller
   (`org.tizen.litewebappservice` → `launch_app(..., payload s, ...)`) but have
   not yet proven its `payload`/app_control reaches the pool bundle to inject
   `__AUL_LOADER_PATH__`. See [App Launch Pool](docs/attack-surface/10-app-launch-pool.md).
2. **World-open `/dev/i2c-*` ioctls** — exposed to uid 5001; classic 4.1.10
   SoC-driver bug class, needs controlled fuzzing. See
   [Kernel Assessment](docs/attack-surface/07-kernel.md).
3. **Unidentified root listener on port 15500** — not yet mapped to a daemon.
4. **Offline firmware patch / reflash** — inject `ps_*` credential XML, patch a
   root daemon, or ship a persistent root helper in the extracted rootfs.
   This is our most promising remaining lane and the least worked.
5. **SMACK / kdbus expertise** — Samsung's kdbus fork reply-lifetime audit, or
   SMACK label-transition quirks that could yield a label/uid transition.

Every avenue we already ruled out is documented in
[Status & Plan](docs/status/11-status.md). **Status of anything that works:
tell us and we'll ship it in tizenMngr.**

## Document Index

Research findings live in [docs/](docs/); start at
[docs/index.md](docs/index.md).

| Doc | Topic |
|-----|-------|
| [01 — Overview](docs/platform/01-overview.md) | Device, goal, constraints, terminology |
| [02 — Access Channels & Tooling](docs/platform/02-access-tooling.md) | Access model + tooling: dev-mode, widget service, Node, D-Bus, WGT signer, NVRAM, `tv.sh` |
| [03 — Execution Model](docs/platform/03-execution-model.md) | SFD-UEP kernel exec gate and its consequences |
| [04 — D-Bus Security](docs/attack-surface/04-dbus-security.md) | CVE-2018-16262..16268 audit + system-bus policy analysis |
| [05 — Privileged Services](docs/attack-surface/05-privileged-services.md) | ps_* credential model, live auth gate, appbinary-manager |
| [06 — SUID & Daemons](docs/attack-surface/06-suid-daemons.md) | wasutility, kfactoryd, deviced, factory-service |
| [07 — Kernel Assessment](docs/attack-surface/07-kernel.md) | Kernel 4.1.10 facts + CVE feasibility |
| [08 — JIT Sandbox](docs/attack-surface/08-jit.md) | V8 JIT shellcode primitive + syscall whitelist |
| [09 — System Bus Surface](docs/attack-surface/09-system-bus-surface.md) | Aug 2026 live bus sweep (reach vs escalate) |
| [10 — App Launch Pool](docs/attack-surface/10-app-launch-pool.md) | Pool wire format, SMACK gate, uid-200 falsification, litewebappservice lead |
| [11 — Status & Plan](docs/status/11-status.md) | Research status, verdicts, next lanes |
| [Tint Fix](docs/fixes/tint-fix.md) | NVRAM white-balance recovery (pink tint) |

Planned/future work lives in [docs/planned/](docs/planned/).

## Tools

- [tools/tv.sh](tools/tv.sh) — run a shell command on the TV via the widget
  exec endpoint (`TV_IP=192.168.1.145 ./tools/tv.sh '<cmd>'`). Requires the
  widget service (`kdbuswgt01`) installed and running on the TV.

## Headline Findings

- The TV's **SFD-UEP** kernel module signature-gates *every* `execve`/`mmap` of
  code on writable filesystems (RSA-2048). No unsigned native code can run from
  `/tmp`, `/var`, `/opt`, or `/home`. Loop-mounted read-only squashfs is **not**
  a bypass — UEP is per-file.
- **Owner foothold achieved:** widget service command exec + signed `/usr/bin/node`
  (uid 5001) + kdbus D-Bus via `dbus-send`/`busctl`.
- **Root not achieved** on FW 1410 after exhaustive D-Bus sweep: ps_* daemons
  load **no credential XML** (all `CallCommand` auth-rejected); pkgmgr admin
  enforced; kfactory is factory-register I/O only; confirmed sandbox impact is
  **reboot DoS** + **ungated factory NVRAM tampering**.
- The app-launch-pool "native-exec unlock" **does not escalate**: the pool runs
  as uid 5001 (not 200), its children are uid 5001 CapEff=0, and its SMACK
  peer gate rejects the widget. See [App Launch Pool](docs/attack-surface/10-app-launch-pool.md).
- Kernel module signing is **off**, but `ps_insmod` never runs without ps_*
  whitelist config — theoretical insmod chain blocked at daemon auth.
- Kernel CVEs (Dirty COW, etc.) remain **in range** but gated behind the UEP
  native-exec wall unless exploiting via driver/ioctl or offline firmware patch.

## Related

- Working tree (raw notes, not public): `local/tizen-secresearch/`
- Device: UN55MU6290, FW 1410, Tizen 3.0
