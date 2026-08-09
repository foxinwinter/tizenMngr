# 04 — Execution Model (SFD-UEP)

## The exec gate

Every "cannot exec `/tmp` script / cannot mmap `.node` addon / EPERM on exec"
failure traced to one Samsung kernel module: **SFD (Security Filter Driver)
with UEP (Unauthorized Execution Prevention)** — a signature-verification gate
on file execution. It is NOT SMACK (SMACK hooks verified identical to
upstream).

## How it works

- LSM hook `security_bprm_check` → `SfdUepVerifyExecutableBinary` (execve gate).
- LSM hook `security_file_mmap` → `SfdUepVerifyDynamicLibrary` (dlopen/mmap gate).
- Any `execve` of a file on a writable filesystem — or matching
  `CONFIG_SECURITY_SFD_RWDEV_PREFIXES` = `/opt:/tmp:/var:/home` — requires an
  **RSA-2048 PKCS#1-v1.5 SHA-256 signature appended to the ELF**.
- Absence/corruption of the signature → `EPERM`.
- Files on the read-only `/` mount bypass UEP (hence `/bin/sh`, `dbus-send`,
  `busctl`, `/usr/bin/node` all execute fine).

## Verified facts

- `cp /bin/ls /tmp/x; /tmp/x` → `EPERM` 126.
- `LD_PRELOAD` of a copied libc → `failed to map segment` + rtld abort.
- A loop-mounted **read-only** squashfs is **NOT** a bypass: exec of a payload
  inside it → `rc=126 Operation not permitted`. UEP enforces **per-file /
  per-inode**, not mount-writability. (Tested via the appbinary-manager mount
  round-trip, see [07 — Privileged Services](07-privileged-services.md).)
- Kernel strings confirmed in the firmware uImage: `SfdUepVerifyExecutableBinary`,
  `SfdUepVerifyDynamicLibrary`, `SfdCheckFileIsInRW`,
  `SfdUepReadSignatureFromFile`, `SfdPerformBlocking`,
  `SfdUepHandleVerificationResult`, `SfdUepRunCheckThread`.

## Consequences for attack design

- NO unsigned native code can ever run from `/tmp`/`/var`/`/opt`/`/home` or
  from writable mounts. The signature may be per-device (DUID-bound) — it
  cannot be forged without the private key.
- All attack paths must use either:
  1. **Pre-signed binaries already on the RO `/` mount** (dbus-send/busctl/node
     — the D-Bus and JS routes, both live), or
  2. **in-process memory corruption** (renderer/JS engine) for native exec.

## Reference

Samsung's SFD source is available in public kernel trees
(`sfd/SfdUepHookHandlers.c`, `SfdConfiguration.c`, `SfdEntry.c`,
`UepConfig.h`, `include/Sfd.h`). The firmware kernel was rebuilt in
Jun 2025 (banner: `4.1.10`, gcc 4.9.2) — treat the banner as untrusted;
fixes may be backported without a version bump.
