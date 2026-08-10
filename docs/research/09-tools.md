# 09 — Tooling

## WGT signer (`tools/sign-wgt.py`)

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
kernel-level UEP exec gate ([04 — Execution Model](04-execution-model.md)).

## Hand-rolled D-Bus client (rawdbus)

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

## NVRAM access (factory-service)

The reliable NVRAM channel (no exec, no ioctl needed) is the factory-service
D-Bus interface:

- **Write**: `org.tizen.tv.factory-service` `/TIFacSerObj`
  `SetParameter` (`ii` = SID + value) → reply `(i) 1` = success. Persists
  across reboot.
- **Read-back**: `GetUidItem` (`iii` = SID, 0, 1) → `((value,), (1,))`. This is
  the ONLY clean read-back (`GetItem`/`GetStrItem`/`GetFString` mask the value
  bytes as `[Invalid UTF-8]`).
- Used to fix a corrupted white-balance item (green gain SID 84 = 1 → pink
  tint). Recovery procedure: `fixes/tint-fix.md`.

**Security note:** this interface is **ungated** on the system bus from the
widget — persistent config tampering (panel, hotel mode, feature flags) without
root. Not code execution; can brick-by-config. Automation-service commands can
have hardware side effects; probe carefully.
