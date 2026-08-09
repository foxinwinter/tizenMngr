# USB-Backed Widget Loading & UI-Preserving App Injection — UN55MU6290 (Tizen 3.0, FW 1410)

Future-use design note: run a `.wgt` app that shows up in the normal Smart Hub UI
while the bulk of its files live on USB (internal eMMC is small), and do it
without disturbing the normal UI.

## How `.wgt` files load / run on Tizen

- `.wgt` = ZIP package: `config.xml` (W3C widget spec, declares appid/name),
  app files (`index.html`, JS), optional `signature.xml`.
- **Install**: `pkgcmd` validates the signature against the TV's cert store,
  unpacks to the apps dir (e.g. `/opt/usr/apps/<appid>/` — exact path is
  Tizen-version dependent), and registers the app in the AppManager DB.
  Signature enforcement happens **at install time only**.
- **Run**: `wrt-launcher` (web runtime) reads the installed app's files from the
  apps dir and executes them as the sandboxed widget uid (5001 on MU6-series).
- A widget does **not** grant privilege — it is the sandboxed context this
  project's exploit escapes. Running a `.wgt` ≠ root.
- The runtime has **no "run from USB" mode**; the TV UI's "Install from USB"
  copies to internal storage first.

## "Appears in normal Smart Hub UI" = 3 things

1. Valid `config.xml` + `icon.png` present in the app dir.
2. An AppManager DB entry for that appid.
3. Runtime can load the files at launch (files reachable when clicked).

## Approach A — Legit Developer Mode (UI-safe, no root)

- Install the official **Samsung Developer Mode** app (free from the store).
- Push a test-signed `.wgt` over the network (Remote Test / SDK flow).
- Registers through the official stack → appears in Smart Hub cleanly.
- Downside: dev-mode apps install fully to internal (still need stub→USB
  split for large content) and Samsung can remove/disable dev mode.

## Approach B — Root-direct registration (full control, persistent, prefered)

1. Internal: a tiny **stub app** (few KB): `config.xml` + `icon.png` +
   `index.html`.
2. Everything else on USB (mount path e.g. `/mnt/udisk/...` — enumerate with
   `mount`/`df` after root).
3. Connect stub → USB bulk:
   - **Symlink the app dir**: register appid `foo.bar.baz`, app dir is a
     symlink `/opt/usr/apps/foo.bar.baz -> /mnt/udisk/myapp/`. USB must be
     mounted **before** Smart Hub scans, else the tile shows but launch fails.
   - **Boot-time bind mount**: small root init/daemon runs
     `mount --bind /mnt/udisk/myapp /opt/usr/apps/foo.bar.baz` at boot; more
     robust against scan timing. ( PREFERRED )

## Preserving the normal UI — rules

- Only **add** one entry; never modify existing ones.
- Back up the app DB + apps dir before any change (trivial with root).
- Use a valid unique appid, well-formed `config.xml`, real icon, sane category
  so it lands in a strip properly.
- Be aware of `pkgmgr` integrity/audit passes that can "reset" a DB they deem
  corrupt — the main way the UI could be disturbed. Test on-device, write the
  DB atomically, keep the backup for instant restore.
- Smart Hub caches the app list → restart Home or reboot after registering.
- If anything breaks: restore backup → UI intact.

## Open items to confirm post-root

- Exact apps dir path.
- Exact AppManager DB path + format (sqlite/json).
- USB mount path + whether mounted `noexec` (remount with `exec` if so).
- Smart Hub scan timing and any integrity/audit behavior.
