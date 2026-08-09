# tizenMngr

Security research on a Samsung UN55MU6290 smart TV (TizenOS 3.0, firmware 1410).
This repository is the **public documentation** for the research: findings,
analysis, and methodology only. No exploit code, no live-network specifics,
no credentials.

All work was performed on the owner's own device for research purposes.
Tizen 3.0 is EOL (2017); no further firmware patches exist.

## Document Index

| Doc | Topic |
|-----|-------|
| [01 — Overview](docs/01-overview.md) | Device, goal, constraints, terminology |
| [02 — Access](docs/02-access.md) | The access model: dev-mode, widget service, Node, D-Bus |
| [03 — D-Bus Security](docs/03-dbus-security.md) | CVE-2018-16262..16268 audit + system-bus policy analysis |
| [04 — Execution Model](docs/04-execution-model.md) | SFD-UEP kernel exec gate and its consequences |
| [05 — Kernel Assessment](docs/05-kernel.md) | Kernel 4.1.10 facts + CVE feasibility |
| [06 — JIT Sandbox](docs/06-jit.md) | V8 JIT shellcode primitive + syscall whitelist |
| [07 — Privileged Services](docs/07-privileged-services.md) | ps_mount/ps_insmod/ps_mknod credential model + appbinary-manager |
| [08 — SUID & Daemons](docs/08-suid-daemons.md) | wasutility (SUID), kfactoryd, rmdemon, canalysis-daemon |
| [09 — Tooling](docs/09-tools.md) | WGT signer, hand-rolled D-Bus client |
| [10 — Status & Plan](docs/10-status.md) | Research status, verdicts, open items |

## Headline Findings

- The TV's **SFD-UEP** kernel module signature-gates *every* `execve`/`mmap` of
  code on writable filesystems (RSA-2048). No unsigned native code can run from
  `/tmp`, `/var`, `/opt`, or `/home`. A loop-mounted **read-only** squashfs is
  **not** a bypass — UEP enforces per-file, and exec is still denied.
- The system/session D-Bus buses are **kdbus-only** (no unix sockets), and the
  bus is reachable from the sandboxed widget via the TV's own signed
  `dbus-send`/`busctl` binaries. This gives unprivileged code real D-Bus
  access to root services (CVE-2018-16266 class).
- `ps_insmod` / `ps_mknod` (root) wrap `/sbin/insmod` and `/bin/mknod` with
  **no command-path regex** — only a caller-exe whitelist. The gate is the
  calling process identity, not the argument.
- Kernel CVE feasibility on 4.1.10 ranks Dirty COW (CVE-2016-5195) highest,
  but all kernel paths are gated behind the native-exec wall.

## Related

- Working tree (raw notes, not public): `local/tizen-secresearch/`
- Device: UN55MU6290, FW 1410, Tizen 3.0
