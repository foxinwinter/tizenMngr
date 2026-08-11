# 02 — Access Channels & Tooling

How we reach the TV and run code as the owner user. Everything here is
**owner-level (uid 5001)** — none of it is root.

## Dev-mode (sdb)

Samsung Developer Mode app enables sdb (Smart Development Bridge) over the LAN.

```bash
sdb connect <tv-ip>                  # dev-mode host IP must be the PC's
sdb -s <tv> shell 0 applist          # enumerate installed apps
sdb -s <tv> shell 0 was_execute <appid>   # launch an app
sdb -s <tv> capability               # device capabilities
```

Restrictions observed:

- Interactive `sdb shell` returns `closed` — `intershell_support:disabled`.
- Only fixed commands via `sdb shell 0 <cmd>` (`applist`, `was_execute`, `push`).
- `appcmd_support:disabled` — cannot run arbitrary app management.
- `rootonoff_support:disabled` — `sdb root on` denied.
- `filesync_support:push` only — files push to the TV, pull is unsupported.

### Capability profile (Tizen 3.0)

```
platform_version:3.0
product_version:3.0
sdbd_version:2.2.31
cpu_arch:armv7
profile_name:tv
vendor_name:Samsung
intershell_support:disabled
rootonoff_support:disabled
filesync_support:push
appcmd_support:disabled
secure_protocol:enabled
```

## Widget service exec channel

The installed widget service (`kdbuswgt01`, uid 5001, SMACK label
`User::Pkg::kdbuswgt01`) exposes an HTTP exec endpoint that runs
`child_process.exec` inside the app's sandbox. This is the stable command
runner used throughout the research — it is **not** a root shell, but it is a
reliable way to run commands inside the app context.

An accompanying host-side HTTP listener receives results/telemetry from the
TV (the TV has no convenient shell).

## Node.js exec (owner-level JS)

`/usr/bin/node` on the read-only `/` mount is `_`-labeled (SMACK floor) and is
**not** subject to the writable-mount exec gate (see
[Execution Model](03-execution-model.md)). Therefore:

```bash
echo <base64-js> | base64 -d | node
```

runs arbitrary JavaScript (Node v4.4.3) as uid 5001. This is the owner-level
code-exec primitive. V8 JIT quirks of this Node version are covered in
[JIT Sandbox](../attack-surface/08-jit.md).

## D-Bus access

The system and session D-Bus buses are kdbus-backed (no unix sockets). The
TV's signed `dbus-send`, `busctl`, `gdbus`, and `dbus-daemon` binaries on the
RO `/` mount drive kdbus directly and run fine under the widget's SMACK label.

- `dbus-send --system ... ListNames` → full well-known-name list.
- `busctl list` works; `busctl call` works against real service names (the
  driver name resolution quirk requires `dbus-send` for
  `org.freedesktop.DBus` itself).
- Full details: [D-Bus Security](../attack-surface/04-dbus-security.md).

## Identity summary

| Attribute | Value |
|-----------|-------|
| UID | 5001 (owner) |
| GID | 100 (users) |
| SMACK label | `User::Pkg::kdbuswgt01` |
| Node | v4.4.3 |
| Widget service | `kdbuswgt01` |

## Tooling

### WGT signer (`tools/sign-wgt.py`)

Reconstructed the Tizen WGT signer (author + distributor) in Python.
Reproduces `author-signature.xml` + `signature1.xml` **byte-for-byte** against
a reference WGT, and all zip members byte-identical.

Key format facts locked in:

- RSA-SHA512; exc-c14n SignedInfo; c14n11 `#prop` Object with the xmldsig
  default ns injected on the standalone Object root.
- ALL base64 (digests, SignatureValue, X509Certificate) wrapped at **76** chars
  (MIME), not 64.
- `<SignedInfo>` emitted WITHOUT inline `xmlns` (inherited).
- File order `config.xml, index.html, icon.png, icon_16b9.png, service/...`;
  URI-encoded paths (`service%2F...`).
- `<dsp:Identifier></dsp:Identifier>` EMPTY for both author and distributor.

Usage: `python3 tools/sign-wgt.py <src_dir> <out.wgt>`.

Note: WGT signing is an install-time gate only; it is unrelated to the
kernel-level UEP exec gate ([Execution Model](03-execution-model.md)).

### Hand-rolled D-Bus client (rawdbus)

A minimal pure-libc D-Bus wire-protocol client (no libdbus/glib — those
headers aren't in the firmware). Works end-to-end
(AUTH → Hello → method_call → parse return) against a local session bus.

Wire-format findings (learned by capturing libdbus's own bytes via an
LD_PRELOAD write-hook and diffing):

- Fixed header is 16 bytes: endian(1)+type(1)+flags(1)+version(1)+
  bodylen(4)+serial(4)+fieldslen(4).
- Header-field structs `{y,v}` are 8-aligned (variant alignment); the
  variant's signature string is u8-len+char+nul (NOT u32, sigs ≤255), written
  with NO alignment; the value string is 4-aligned (u32 len + chars + nul).
- `fields_len` counts bytes after the 16-byte header excluding the array's
  trailing pad-to-8; body_length = argument bytes only (0 for no-args).
- Message type byte: 1=method_call, 2=method_return, 3=error, 4=signal. Loop
  reading until type==2 (bus interleaves NameAcquired/NameOwnerChanged signals).
- SASL EXTERNAL on unix-stream: leading `\0`, then
  `AUTH EXTERNAL <hex-uid>`; handle `DATA` continuation.

A pure-JS port of the same wire format was packaged as a widget service
(`rawdbus-wgt`) that POSTs results to the host — used to probe kdbus before
the signed-tools route was found.

### NVRAM access (factory-service)

The reliable NVRAM channel (no exec, no ioctl needed) is the factory-service
D-Bus interface:

- **Write**: `org.tizen.tv.factory-service` `/TIFacSerObj`
  `SetParameter` (`ii` = SID + value) → reply `(i) 1` = success. Persists
  across reboot.
- **Read-back**: `GetUidItem` (`iii` = SID, 0, 1) → `((value,), (1,))`. This is
  the ONLY clean read-back (`GetItem`/`GetStrItem`/`GetFString` mask the value
  bytes as `[Invalid UTF-8]`).
- Used to fix a corrupted white-balance item (green gain SID 84 = 1 → pink
  tint). Recovery procedure: [fixes/tint-fix.md](../fixes/tint-fix.md).

**Security note:** this interface is **ungated** on the system bus from the
widget — persistent config tampering (panel, hotel mode, feature flags) without
root. Not code execution; can brick-by-config. Automation-service commands can
have hardware side effects; probe carefully.

### Host helper

- `tools/tv.sh` — run a shell command on the TV via the widget exec endpoint
  (`TV_IP=<tv-ip> ./tools/tv.sh '<cmd>'`).
