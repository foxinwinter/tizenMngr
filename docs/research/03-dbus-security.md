# 03 — D-Bus Security

## Transport: kdbus only

- `kdbusfs` mounted at `/sys/fs/kdbus`; system bus at `/sys/fs/kdbus/0-system/bus`,
  session at `/sys/fs/kdbus/<uid>-user/bus`, plus `0-securezone` and `control`.
- **No unix-socket D-Bus exists anywhere** on the device.
- SMACK does **not** gate the bus fd for the unprivileged widget — opening the
  system bus succeeds. Enforcement is entirely in D-Bus policy files +
  per-call SMACK checks.

## CVE-2018-16262..16268 family

Source: DEFCON 26 — Dongsung Kim & Hyoung Kee Choi, "Your Watch Can Watch You"
(also Samsung's fix commits on review.tizen.org). All affect Tizen before
5.0 M1 — this device (Tizen 3.0) is in scope.

| CVE | Service | Unprivileged process can... | CVSS |
|-----|---------|------------------------------|------|
| 16262 | pkgmgr | install/decrypt/kill packages | 8.8 |
| 16263 | PulseAudio | control A2DP MediaEndpoint | 8.8 |
| 16266 | Enlightenment | fully control/capture windows | 8.1 |
| 16267 | system-popup | trigger poweroff menu, arbitrary popups | 8.1 |
| 16264 | BlueZ | partially control BT / acquire info | 6.5 |
| 16265 | bt/bt_core | create system UI, control pairing | 6.5 |
| 16268 | SoundServer/FocusServer | play arbitrary sound/DTMF | 4.3 |

## Static policy audit (firmware 1410, extracted rootfs)

Policies inspected from `/etc/dbus-1/system.d/` + `/usr/share/dbus-1/system.conf`:

- **System bus default is PERMISSIVE**: `<policy context="default">` allows all
  `method_call`/signal/reply types. Enforcement relies solely on
  `system.d/*.conf` + SMACK.
- **`org.tizen.pkgmgr.conf` — PATCHED** (CVE-2018-16262 NOT applicable):
  install/uninstall/kill/decrypt/move all gated by
  `http://tizen.org/privilege/packagemanager.admin`.
- **`org.enlightenment.wm.conf` — VULNERABLE** (CVE-2018-16266 confirmed):
  `<allow send_destination="org.enlightenment.wm"/>` with NO privilege checks.
  Impact: fully control/capture windows on the root-uid WM.
- **`pulseaudio-system.conf` — PARTIALLY VULNERABLE** (16263): only a single
  check on `SetVolumeLevel`; A2DP MediaEndpoint control ungated.
- **`sound-server.conf` / `focus-server.conf` — VULNERABLE** (16268 confirmed):
  full `<allow send_destination>` for `org.tizen.SoundServer` /
  `org.tizen.FocusServer`, no checks. Impact: play arbitrary sound/DTMF.
- **No policy conf at all** (any process can call, subject only to SMACK):
  `com.samsung.ht.IControl`, `com.samsung.tizen.vddmr`,
  `org.tizen.capi_smsource.server`, `org.tizen.GDBus.*`
  (RemoteManagement, RemoteShopContentManagement, SmartHubConnectionTest),
  `org.tizen.registerdevice.*`, `org.tizen.tv.system.tvtimer`,
  `org.tizen.virtualkeyd`.

### Verdict

16262 dead (patched), 16268 confirmed (low impact), 16266 confirmed (window
control — needs the WM interface analysis to become escalation), 16263/64/65
partial. The family alone does not obviously yield root.

**Live follow-up (2026-08-09):** pkgmgr `.admin` methods remain denied from the
widget (`<check>` fires even though `security-manager`/`cynara` are stub units).
Full bus sweep: [11 — System Bus Surface](11-system-bus-surface.md).

## Live call demonstrated (CVE-2018-16266 class)

From the unprivileged widget, a real D-Bus method call to the root-uid WM
succeeded with **no policy enforcement**:

```
dbus-send --system --print-reply --dest=org.enlightenment.wm \
  /org/enlightenment/wm org.enlightenment.wm.dpms.get
→ int32 0
```

### Enlightenment WM interface (introspected live)

- `org.enlightenment.wm.dpms`: `set(i)`, `get()→i`
- `org.enlightenment.wm.Test` (custom, the 16266 attack surface):
  `GetWinInfo`, `RegisterWindow`, `EventKey`, `EventFreeze`, `DPMS`,
  `EventMouse`, `DeregisterWindow`, `HWC`, `GetCurrentZoneRotation`,
  `SetWindowStack`, `ChangeZoneRotation`, `GetWinsInfo`
- plus `Properties` + `Introspectable`

Enlightenment runs as root. Successful `wm.Test` calls are root-context
effects (`EventKey`/`EventFreeze`/`DPMS`/`ChangeZoneRotation` map to the
"arbitrary window control / key injection" class).

## Noted root services on the system bus

- `com.safe.ps_insmod`, `com.safe.ps_mknod`, `com.safe.ps_mount`,
  `com.safe.ps_umount` — **root** (Samsung dev-tool helpers; see
  [07 — Privileged Services](07-privileged-services.md))
- `enlightenment` — **root**
- `org.tizen.FocusServer` — **root**
- `fi.w1.wpa_supplicant1`, `org.pulseaudio.Server`,
  `org.projectx.bt_monitor` — root
- `org.tizen.pkgmgr` — activatable (package manager)
- `net.connman`, `org.freedesktop.systemd1`, `com.samsung.*`, `Sim.Daemon`,
  `com.native.BT_APP_DBUS`, `com.projectx.bt_monitor`, `tvs-daemon`, `amd`,
  `tv-viewer`, `stability-monitor`, `pms-monitor`, `security_manager`,
  `audio_effect`, `hmtvr_*`, `SMsg-Daemon-*`
