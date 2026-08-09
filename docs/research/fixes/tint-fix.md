# Pink/Magenta Tint Fix — UN55MU6290 (Tizen 3.0, FW 1410)

One-command recovery for the magenta/pink display tint that can appear after
automation/factory commands touch the white-balance block.

## Root Cause

The TV's green-channel **gain** item was corrupted to `1` (out of 0–255).
With essentially zero green, the panel renders magenta/pink. The WB offsets
(SID 95/96) were a red herring — they persisted correctly but never restored
the color because the gain was the real problem.

- Corrupted: `SID 84 = 1` (factory default `128`)
- Also observed corrupted: `SID 82 = 200`, `SID 83 = 200`, `SID 85 = 154`,
  `SID 94 = 145` (all default `128`)

## Fix

Write the full WB gain block back to factory defaults, then power-cycle.

```bash
# From the widget shell (host-side helper: tv.sh '<cmd>')
for s in 82 83 84 85 94; do
  tv.sh "dbus-send --system --print-reply --dest=org.tizen.tv.factory-service /TIFacSerObj org.tizen.tv.factoryservice.SetParameter int32:$s int32:128"
done
```

- `SetParameter` signature is `ii` (SID, value); reply `(i) 1` = success.
- The write persists to NVRAM across reboot (no save command needed).
- A **power-cycle** (pull/replug power or hold the power button) is required —
  `systemctl reboot` and `/proc/sysrq-trigger` are denied under the widget's
  SMACK context.

If the tint returns after power-cycle, the write didn't take; re-run the loop
and verify with a read-back (below) before cycling power again.

## Verify

```bash
# GetUidItem (SID, 0, 1) → ((value,), (1,))
for s in 82 83 84 85 94 95 96; do
  tv.sh "gdbus call --system --dest org.tizen.tv.factory-service --object-path /TIFacSerObj --method org.tizen.tv.factoryservice.GetUidItem $s 0 1"
done
```

Expected healthy values (all factory defaults):

| SID | Role | DValue |
|-----|------|--------|
| 82  | WB gain (R) | 128 |
| 83  | WB gain (G) | 128 |
| 84  | WB gain (G) | 128 |
| 85  | WB gain (B) | 128 |
| 94  | WB gain | 128 |
| 95  | WB offset | 32 |
| 96  | WB offset | -58 |
| 97  | WB offset | 0 |
| 98  | WB offset | 0 |

`GetUidItem` is the **only** clean read-back — `GetItem`/`GetStrItem`/
`GetFString` mask the value bytes as `[Invalid UTF-8]`.

## Notes

- Symptoms: pink/magenta cast on menus, OSD, and all inputs; survives reboot
  and TV-side factory reset.
- `SID 95 = 8` / `SID 96 = -55` readings were also observed when corrupted;
  do not treat these as the cause — check the gains first.
- This is a per-device NVRAM fix; no firmware change is involved.
