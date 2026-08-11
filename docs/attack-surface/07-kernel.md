# 07 — Kernel Assessment

## Facts

- Live kernel: `Linux version 4.1.10 (abuild@A0919LHG) (gcc 4.9.2) SMP PREEMPT ... Jun 11 2025` — Samsung rebuild; **banner untrusted**.
- No `/proc/config.gz`, no IKCONFIG, no `/proc/kallsyms`; `kptr_restrict=0`, `dmesg_restrict=0`.
- Subsystem probes: KEYS present, PACKET present, DCCP absent, `n_hdlc` absent,
  user namespaces absent, no eBPF knob.

## CVE feasibility (4.1.10)

| CVE | Subsystem | Status | Feasibility |
|-----|-----------|--------|-------------|
| CVE-2016-5195 (Dirty COW) | mm/COW | in range | HIGH |
| CVE-2016-8655 (packet ring race) | net/packet | in range | MED |
| CVE-2016-0728 (keyring refcount) | security/keys | in range | MED |
| CVE-2017-6074 (DCCP UAF) | net/dccp | DCCP not built | DEAD |
| CVE-2017-2636 (n_hdlc race) | drivers/char/n_hdlc | not built | DEAD |
| CVE-2017-16995 (eBPF) | needs 4.14+ | out of range | DEAD |
| CVE-2017-1000112 (netlink) | needs 4.4+ | out of range | DEAD |
| 2016-9793 / 2017-7308 / 2016-7117 / 2016-4557 / 2016-7042 / 2015-1805 | — | not in range / fixed | DEAD |

Ranking if native exec were ever solved: **5195 > 8655 > 0728**.

## The gate: native-exec wall

All kernel exploits are gated behind the writable-mount exec block
([Execution Model](../platform/03-execution-model.md)). Without unsigned native code
running, no local kernel exploit can be exercised. Details on the one partial
escape (Node JIT) in [JIT Sandbox](08-jit.md).
