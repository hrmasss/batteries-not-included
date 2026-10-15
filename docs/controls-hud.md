# Controls, camera and HUD

How the phone controls, the camera and the HUD fit together, and the hooks other parts plug
into. Specs: US-05, US-10, US-23 to US-26, US-42 and T-80 to T-88 in the workspace's
`docs/specs/`.

## Pieces

| Piece | File | What it does |
|---|---|---|
| Stick logic | `src/controls/touch_stick.gd` | Capture radius, knob clamp, no dead zone, fire past the ring, knob return, floating, inverts |
| Layout | `src/controls/touch_layout.gd` | Where each stick and button sits, mirrored for left hands |
| Touch controls | `src/controls/touch_controls.gd` | Reads screen touches, draws sticks and buttons, fills an `InputIntent` |
| Touch input source | `src/controls/touch_input.gd` | `InputSource` for `GameView`: touch while a thumb is down, desktop devices otherwise |
| Player settings | `src/controls/control_settings.gd` | Stick size, opacity, floating, left-handed, inverts, fire button, look-ahead, panning, zoom speed and mode, shake, volumes. Saved in `user://settings.cfg` |
| Camera logic | `src/camera/camera_rig.gd` | Anchor, look-ahead by weapon, zoom ladder with per-weapon memory, shake, equal view area |
| Camera node | `src/view/game_camera.gd` | Applies the rig to a `Camera2D` |
| Values | `src/camera/view_rules.gd` | T-80 to T-87 and the blast shake (T-63), read from the ruleset's `camera` group |
| HUD | `src/hud/hud.gd` | Health and battery, ammo, grenades, clock, scores, kill feed, respawn panel, radar arrows, hit direction |
| Radar logic | `src/hud/radar.gd` | Which off-screen toys get an arrow (T-87) |
| Player HUD | `src/hud/player_hud.gd` | Adds the HUD and touch controls to a view and wires them to the camera |
| Team marks | `src/team/` | Team colours and shapes, the outline and battery tint, name tags |

## Ticks and frames

```
each tick:   source.intent_for() -> InputIntent -> player_hud.on_intent() -> sim.step()
                                                  (zoom tap, camera aim)
each frame:  camera.follow(toy drawn position)  ->  player_hud.frame()  ->  Hud reads HudSource
```

Nothing here decides a rule. Fire, buttons and sticks go into the intent; the match decides
what they do.

## Hooks for other tasks

**Combat.** The HUD reads a `HudState` filled by a `HudSource`. Today `SimHudSource` takes
health and battery from the sim and everything else from `CombatStub`: weapon, magazine,
reserve, grenades by kind, clock, scores, kill feed, pops, respawn countdown, hits, teams,
names, and "fired" for the radar. When combat lands, fill those from the sim in
`SimHudSource.read` and drop the stub. The camera needs each weapon's allowed zoom levels and
look-ahead factor: add `zoom` and `look_ahead` to the weapon rows and read them in
`WeaponView.for_weapon` instead of its table. Call `camera.rig.blast(distance, power)` for each
blast near the player.

**Art integration.** Put each toy's drawing under a `TeamOutline` (a `CanvasGroup`) and call
`set_team(team)`; -1 is free-for-all. It draws a thin team outline around the whole toy and
tints any child named `Battery`, `BatteryA`, `BatteryB`, `Batteries`, `Wire`, `WireA`, `WireB`
or `Wires` with the team colour, through `modulate` (ship those parts greyscale) or through the
part's own `set_team_color(color)`. Add a `NameTag` next to each other player's toy. The HUD
font is `assets/fonts/LilitaOne-Regular.ttf` (SIL Open Font License, text beside it).

**Settings screen (later).** Change a `ControlSettings`, call `save()`, then
`player_hud.apply_settings()`.

## Demo

`src/app/controls_demo.tscn` runs one player, a teammate and two enemies with the stub filled
in. Scripted runs for screenshots:

```sh
godot --path . --resolution 2400x1080 --fixed-fps 30 --quit-after 330 \
  res://src/app/controls_demo.tscn -- --script=flight --frames=/tmp/frames
```

Scripts: `flight` (simulated thumbs walk, take off, fly a loop, aim, fire, tap zoom), `hud` (a
busy HUD), `popped` (the respawn panel). Flags: `--left-handed`, `--bi` (Batteries Included).
