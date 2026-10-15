# How the code is laid out

The specs live in the workspace (`docs/specs/`); this page maps their parts onto folders.

| Folder | Part (03_architecture) | Holds |
|---|---|---|
| `src/rules/` | Ruleset and content | `RulesetSchema` (names, T-IDs, ranges), `Ruleset` (the values), `RulesetLoader` (reads, checks, refuses, saves) |
| `data/rulesets/<id>/` | Ruleset and content | The values: `ruleset.cfg` plus one file per tuning group, T-IDs in comments |
| `src/sim/` | Match server | `MatchSim`, `SimToy`, `ToyMotor` (movement rules), `SimClock` (60 Hz), `InputIntent`, `ScriptedInput`, `Drills` |
| `src/maps/` | Ruleset and content | Map node types: `GameMap`, `Terrain`, `SpawnPoint`, `PickupPoint`, `TeamBase` |
| `maps/` | Ruleset and content | The maps themselves, one folder each |
| `src/view/` | Game app | `GameView` (runs the clock, feeds intents, draws), `ToyView`, `GameCamera`, `DebugOverlay`, input sources |
| `tests/` | | GUT tests: `unit/`, `sim/` (criteria with check "Sim"), `view/` |
| `tools/` | | `test.sh`, `shot.sh`, `make_blockout.gd` |

## The split (rules A1 to A3)

```
 device input ──> InputSource ──> InputIntent ──┐
 (keys, pad,      (desktop,       one per toy,  │  MatchSim.step()   one fixed tick, 60 Hz
  touch, bot,      scripted,      per tick      ├─────────────────> SimToy state
  network)         touch later)                 │                       │
                                                │                       v
                         SimClock: frames in, whole ticks out      ToyView draws between
                                                                   the last two ticks
```

- **The sim decides; the view draws.** Nothing under `src/sim/`, `src/rules/` or `src/maps/`
  reads device input, knows a view class, or steps from an engine frame callback.
  `tests/unit/test_architecture.gd` checks that.
- **One intent shape.** Keyboard, gamepad, touch, bots, replays and the network all produce
  `InputIntent`. The sim takes `intent.sanitized()`, never raw numbers.
- **Fixed clock.** `SimClock` turns frames of any length into 60 Hz ticks, so a run gives the
  same path at 30, 60 or 120 fps (US-04.2, NF-12). The view draws between the last two tick
  states.
- **Rules are data.** `ToyMotor` reads every number from the `Ruleset`; the only literals it
  holds are 0, 1 and two named solver constants (checked by a test). Add a value: one row in
  `RulesetSchema.FIELDS`, one typed field on `Ruleset`, one line in the group's `.cfg`.
- **Physics.** Collision uses Godot's physics queries (`CharacterBody2D.move_and_collide`)
  against static terrain, stepped by the sim's own clock in two sub-steps per tick, like the
  classic. Contacts bounce and rub by toy × terrain values from `surfaces.cfg`.

## Coordinates

World space is Godot's 2D space: x right, **y down**, 1 pixel = 1 `u`. Stick and intent vectors
are **y up**, as in the specs. `SimToy.position` is the classic's body origin; the feet are
`-body_bottom` (15 u) below it.
