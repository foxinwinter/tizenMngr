# 06 — JIT Sandbox

Node v4.4.3's V8 JIT (CVE-2017-5121 class) gives uid-5001 arbitrary ARM code
execution via a fake-ArrayBuffer write primitive into a JIT Code object
(`func_obj(0)` shellcode, 24-word EABI). This was fully characterized; it is
**not** an escalation path on its own.

## JIT → libc control transfer: blocked

Every attempt to jump from the JIT region into a libc function
(`getpid`, `abs`, `memcpy`, `strlen` — address verified identical to rootfs
libc) segfaulted at the transfer, in all variants:

- `blx r7` → ARM-mode libc fn: SIGSEGV
- `blx r7` → Thumb-2 libc fn (correct mode switch): SIGSEGV
- `ldr pc,[pc,#imm]` indirect jump: SIGSEGV
- With 8-byte SP alignment: SIGSEGV
- Control (intra-JIT `blx` to own code): returns fine

The "call libc `syscall()` to bypass the JIT syscall mask" plan is dead.

## JIT syscall filter: fixed whitelist

Direct `svc #0` from the JIT region is filtered per syscall number.

**Allowed** (return normally): futex, sched_yield, gettimeofday, clock_gettime,
nanosleep, brk, munmap, mprotect, madvise, mlock, mlockall, msync, mincore,
mremap, prctl.

**Blocked** (process killed — SIGSEGV, SIGILL for add_key): socket, setsockopt,
fcntl, getppid, clone, pipe, read, write, close, open, openat, mmap, keyctl,
add_key, request_key, getdents, kill, set_tid_address, getpid, getuid/geteuid.
(getrlimit/uname return -ENOSYS but execute.)

The whitelist is exactly "memory management + sync/clock" — what a JIT'd JS
engine needs at runtime.

## Implications

- **GhostLock (futex-PI + keyring UAF): DEAD** — keyctl/add_key/request_key
  blocked from JIT; no Node API creates kernel keys.
- No known 4.1.10 kernel bug is reachable with only the whitelist
  (file/network/keyring/clone-based exploits all need blocked syscalls).
- **Asymmetry**: Node's own libc syscalls are unfiltered (return address not
  in the JIT region) — `fs`/`net`/`child_process` all work normally. But Node
  has no API for arbitrary syscalls, and JIT→libc is blocked. So: JIT can't do
  dangerous syscalls, Node can't make arbitrary syscalls.
- Pivot candidates instead: D-Bus to root daemons and world-writable `/dev`
  nodes (see [11 — System Bus Surface](11-system-bus-surface.md)). ps_* and
  kernel-exploit paths remain gated ([07](07-privileged-services.md),
  [10](10-status.md)).
