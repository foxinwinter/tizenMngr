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

## Document Index

Research findings live in [docs/research/](docs/research/).

| Doc | Topic |
|-----|-------|
| [01 — Overview](docs/research/01-overview.md) | Device, goal, constraints, terminology |
| [02 — Access](docs/research/02-access.md) | The access model: dev-mode, widget service, Node, D-Bus |
| [03 — D-Bus Security](docs/research/03-dbus-security.md) | CVE-2018-16262..16268 audit + system-bus policy analysis |
| [04 — Execution Model](docs/research/04-execution-model.md) | SFD-UEP kernel exec gate and its consequences |
| [05 — Kernel Assessment](docs/research/05-kernel.md) | Kernel 4.1.10 facts + CVE feasibility |
| [06 — JIT Sandbox](docs/research/06-jit.md) | V8 JIT shellcode primitive + syscall whitelist |
| [07 — Privileged Services](docs/research/07-privileged-services.md) | ps_* credential model, live auth gate, appbinary-manager |
| [08 — SUID & Daemons](docs/research/08-suid-daemons.md) | wasutility, kfactoryd, deviced, factory-service |
| [09 — Tooling](docs/research/09-tools.md) | WGT signer, hand-rolled D-Bus client, NVRAM access |
| [10 — Status & Plan](docs/research/10-status.md) | Research status, verdicts, next lanes |
| [11 — System Bus Surface](docs/research/11-system-bus-surface.md) | Aug 2026 live bus sweep (reach vs escalate) |
| [Fixes — Tint Fix](docs/research/fixes/tint-fix.md) | NVRAM white-balance recovery (pink tint) |

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
- Kernel module signing is **off**, but `ps_insmod` never runs without ps_*
  whitelist config — theoretical insmod chain blocked at daemon auth.
- Kernel CVEs (Dirty COW, etc.) remain **in range** but gated behind the UEP
  native-exec wall unless exploiting via driver/ioctl or offline firmware patch.

## Related

- Working tree (raw notes, not public): `local/tizen-secresearch/`
- Device: UN55MU6290, FW 1410, Tizen 3.0
