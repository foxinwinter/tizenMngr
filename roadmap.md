# tizenMngr — Roadmap

**Status: HALTED** — waiting on full, decently-repeatable root access on the
target (UN55MU6290, TizenOS 3.0, FW 1410). Everything in this roadmap is
contingent on that gate.

## Project goal

tizenMngr is first and foremost an **app** for managing a rooted Samsung Tizen
TV. The security research in this repo exists to reach the state that makes
the app possible. The app itself should eventually provide:

1. **TizenBrew module management**
   - Install / update / remove TizenBrew modules from the device.
   - Manage the TizenBrew standalone service.
2. **Full root app management & installation**
   - Install, uninstall, update any app (WGT/TPK), bypassing the normal
     privilege gates.
   - Manage apps/package DB directly as root.
   - Downgrade / force-install / clear user data per app.
3. **Kernel / root-exploit runner**
   - Since the app talks to the device directly, it should be able to launch
     the kernel / root vulnerability work (i.e. run the root chain) itself.
   - Prerequisite: a reliable, repeatable exploit path.

## Gate: root access

**HALTING CONDITION** — no roadmap items proceed until:

- [ ] Full root access achieved (uid 0 / elevated capability on the TV).
- [ ] The root path is **decently repeatable** (survives reboots, not
      fragile/burning-once).
- [ ] Root survives app/service restarts long enough to be practically useful.

Until then, work is limited to research/docs + keeping the current findings
current.

## Roadmap (ordered after gate opens)

### Phase 0 — Root enablement & persistence
- [ ] Ship the root chain as a repeatable exploit module (see `docs/research/`).
- [ ] Establish a root shell / daemon channel the app can drive.
- [ ] Determine persistence options (survives reboot, dev-mode toggle, etc.).

### Phase 1 — tizenMngr app core
- [ ] App scaffold (Tizen web app, installed via existing dev-mode path).
- [ ] Secure channel to the on-device root service (no plaintext creds).
- [ ] Device info panel (firmware, kernel, model, root status).

### Phase 2 — TizenBrew module management
- [ ] List installed TizenBrew modules.
- [ ] Install / update / remove modules.
- [ ] Manage TizenBrew standalone service lifecycle.

### Phase 3 — Root app management & installation
- [ ] Install / uninstall / update WGT & TPK as root.
- [ ] Package DB management (register, remove, backup/restore).
- [ ] Per-app actions: force-stop, clear data, downgrade, export APK/pkg.

### Phase 4 — Kernel / root-exploit runner
- [ ] Select & launch the root/kernel exploit from within the app.
- [ ] Status/verification of root state after exploit run.
- [ ] Repeatable re-root after reboot or root loss.

## Current research status

See [docs/research/10-status.md](docs/research/10-status.md). TL;DR: owner-level
JS exec + full D-Bus reach achieved; root not yet achieved. Kernel CVEs
(Dirty COW etc.) are in range but gated behind the native-exec wall
([docs/research/04-execution-model.md](docs/research/04-execution-model.md)).
