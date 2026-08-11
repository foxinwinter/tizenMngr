# Document Index

Master catalog for the UN55MU6290 (Tizen 3.0, FW 1410) research. Start with
[01 — Overview](platform/01-overview.md) and [11 — Status & Plan](status/11-status.md).

## Platform

| Doc | Contents |
|-----|----------|
| [01 — Overview](platform/01-overview.md) | Device, goal, constraints, terminology |
| [02 — Access Channels & Tooling](platform/02-access-tooling.md) | Access model + tooling: dev-mode, widget service, Node, D-Bus, WGT signer, NVRAM, `tv.sh` |
| [03 — Execution Model](platform/03-execution-model.md) | SFD-UEP kernel exec gate and its consequences |

## Attack surface

| Doc | Contents |
|-----|----------|
| [04 — D-Bus Security](attack-surface/04-dbus-security.md) | CVE-2018-16262..16268 audit + system-bus policy analysis |
| [05 — Privileged Services](attack-surface/05-privileged-services.md) | `ps_*` credential model, live auth gate, appbinary-manager |
| [06 — SUID & Daemons](attack-surface/06-suid-daemons.md) | wasutility, kfactoryd, deviced, factory-service |
| [07 — Kernel Assessment](attack-surface/07-kernel.md) | Kernel 4.1.10 facts + CVE feasibility |
| [08 — JIT Sandbox](attack-surface/08-jit.md) | V8 JIT shellcode primitive + syscall whitelist |
| [09 — System Bus Surface](attack-surface/09-system-bus-surface.md) | Aug 2026 live bus sweep (reach vs escalate) |
| [10 — App Launch Pool](attack-surface/10-app-launch-pool.md) | Pool wire format, SMACK gate, uid-200 falsification, litewebappservice lead |

## Status / fixes / planned

| Doc | Contents |
|-----|----------|
| [11 — Status & Plan](status/11-status.md) | Research status, verdicts, next lanes |
| [Tint Fix](fixes/tint-fix.md) | NVRAM white-balance recovery (pink tint) |
| [USB Widget Loading (planned)](planned/usb-widget-loading.md) | USB-backed widget loading & UI-preserving app injection |
