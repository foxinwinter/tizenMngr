# 01 — Overview

## Device

- Samsung UN55MU6290 (2017 UHD LED)
- TizenOS 3.0, firmware 1410 (EOL; final build ~2020, no more patches)
- ARMv7 (`cpu_arch:armv7`), profile `tv`

## Goal

1. Gain **owner-level** (uid 5001) code execution on the device.
2. Investigate **privilege escalation** to root.
3. Document findings (this repo).

Research-only; performed on the owner's own TV.

## Why this device

The documented reference root chain for this platform is
CVE-2014-1303 (WebKit CSS UAF → ArrayBuffer overwrite → RWX) plus
CVE-2015-1805 (kernel pipe overflow) — but as this research shows, the
firmware is heavily hardened against both the userland and kernel sides of
that chain.

## Constraints

- TV and research host must be on the same LAN.
- No Tizen Studio toolchain on the research host; `sdb` CLI only.
- No destructive operations on the TV (factory reset, firmware flash) without
  explicit request.
- Native code execution from writable mounts is blocked at the kernel level
  (see [04 — Execution Model](04-execution-model.md)).

## Terminology

| Term | Meaning |
|------|---------|
| SFD-UEP | Samsung Security Filter Driver — Unauthorized Execution Prevention |
| kdbus | In-kernel D-Bus transport (used by Tizen 3.0, no unix sockets) |
| SMACK | Simplified Mandatory Access Control kernel LSM |
| WGT | W3C widget package (`.wgt`), the Tizen web-app format |
| TPK | Tizen native package (`.tpk`) |
| widget service | Background JS process in a Tizen web app (`<tizen:service>`) |
| ABM | `appbinary-manager`, a root D-Bus service for app-binary loop mounts |

## Outcome summary

Owner-level JS execution (via signed `/usr/bin/node`) and full kdbus D-Bus
access from the sandboxed widget were both achieved. **Root escalation has not
been achieved.** A 2026-08-09 system-bus sweep closed most D-Bus LPE paths
(ps_* auth gate empty, pkgmgr admin enforced, kfactory not arbitrary memory).
Remaining lanes: driver/ioctl surfaces, offline firmware patch, and deeper
factory/engineer RE — see [10 — Status & Plan](10-status.md) and
[11 — System Bus Surface](11-system-bus-surface.md).
