# 02 — Access

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
[04 — Execution Model](04-execution-model.md)). Therefore:

```bash
echo <base64-js> | base64 -d | node
```

runs arbitrary JavaScript (Node v4.4.3) as uid 5001. This is the owner-level
code-exec primitive. V8 JIT quirks of this Node version are covered in
[06 — JIT Sandbox](06-jit.md).

## D-Bus access

The system and session D-Bus buses are kdbus-backed (no unix sockets). The
TV's signed `dbus-send`, `busctl`, `gdbus`, and `dbus-daemon` binaries on the
RO `/` mount drive kdbus directly and run fine under the widget's SMACK label.

- `dbus-send --system ... ListNames` → full well-known-name list.
- `busctl list` works; `busctl call` works against real service names (the
  driver name resolution quirk requires `dbus-send` for
  `org.freedesktop.DBus` itself).
- Full details: [03 — D-Bus Security](03-dbus-security.md).

## Identity summary

| Attribute | Value |
|-----------|-------|
| UID | 5001 (owner) |
| GID | 100 (users) |
| SMACK label | `User::Pkg::kdbuswgt01` |
| Node | v4.4.3 |
| Widget service | `kdbuswgt01` |
