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
| Camera logic | `src/camera/camera_rig.gd` | Anchor, look-ahead by weapon, easing to the sim's zoom level, shake, equal view area |
| Camera node | `src/view/game_camera.gd` | Applies the rig to a `Camera2D` |
| Values | `src/camera/view_rules.gd` | T-80 to T-87 and the blast shake strength (T-63), read from the ruleset's `camera` group |
| HUD | `src/hud/hud.gd` | Health and battery, ammo, grenades, clock, scores, kill feed, respawn panel, radar arrows, hit direction |
| Radar logic | `src/hud/radar.gd` | Which off-screen toys get an arrow (T-87) |
| HUD source | `src/hud/sim_hud_source.gd` | Fills the HUD from the sim and combat: toy, fighter and combat events |
| Player HUD | `src/hud/player_hud.gd` | Adds the HUD and touch controls to a view; points the camera at the fighter's zoom and weapon; blast shake |
| Team marks | `src/team/` | Team colours and shapes, the outline and battery tint, name tags |

## Ticks and frames

```
each tick:   source.intent_for() -> InputIntent -> player_hud.on_intent() -> sim.step()
                                                  (camera aim)         (zoom tap is a button)
each frame:  camera.follow(toy drawn position)  ->  player_hud.frame()  ->  Hud reads HudSource
                                                    (rig.set_held(fighter.zoom_level, weapon look_ahead))
```

Nothing here decides a rule. Fire, buttons and sticks go into the intent; the match decides
what they do.

## Hooks for other tasks

**Zoom.** The sim owns the zoom level and the per-weapon memory (`Fighter.zoom_level`,
`zoom_memory`, US-10). The player's zoom mode (US-10.4) goes to the sim through
`CombatSim.set_zoom_mode`, sent by `PlayerHud` at setup and after `apply_settings`. The camera
only eases to the level (T-83). Each weapon row in `weapons.cfg` has `zoom` (T-50) and
`look_ahead` (T-81).

**Combat.** `SimHudSource` reads the fighter (weapon, ammo, grenades, pops, respawn, protection,
pick-up offer), sums kills into scores, and listens to combat events for the kill feed (`pop`),
hit direction (`hit`) and radar alerts (`shot`, `throw`). Blast events (`blast`, with
`shake_reach`) shake the player's camera. Two things are not in the sim yet and are set on the
source by whoever runs the match: player names (`names`, else "Toy N") and the match clock
(`clock`, negative hides it). The match loop should own both.

**Art integration.** Put each toy's drawing under a `TeamOutline` (a `CanvasGroup`) and call
`set_team(team)`; -1 is free-for-all. It draws a thin team outline around the whole toy and
tints any child named `Battery`, `BatteryA`, `BatteryB`, `Batteries`, `Wire`, `WireA`, `WireB`
or `Wires` with the team colour, through `modulate` (ship those parts greyscale) or through the
part's own `set_team_color(color)`. Add a `NameTag` next to each other player's toy. The HUD
font is `assets/fonts/LilitaOne-Regular.ttf` (SIL Open Font License, text beside it).

**Settings screen (later).** Change a `ControlSettings`, call `save()`, then
`player_hud.apply_settings()`.

## Demo

`src/app/controls_demo.tscn` runs one player, a teammate and two enemies with real combat.
Scripts set up moments through combat's own calls (`place_item`, `hurt`). Scripted runs for
screenshots:

```sh
godot --path . --resolution 2400x1080 --fixed-fps 30 --quit-after 330 \
  res://src/app/controls_demo.tscn -- --script=flight --frames=/tmp/frames
```

Scripts: `flight` (simulated thumbs walk, take off, fly a loop, aim, fire, tap zoom), `hud` (a
busy HUD: rifle picked up, two pops, hits, radar, low clock), `popped` (the respawn panel). Flags: `--left-handed`, `--bi` (Batteries Included).
