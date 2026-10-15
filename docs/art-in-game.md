# The art in the game

How the art lab's SVGs become the game's drawing (`src/art/`, `src/view/toy_view.gd`,
`src/view/combat_view.gd`). Specs: `docs/art/` in the workspace, US-03.1, US-03.4, US-11.5,
US-15.1, US-26.1, US-26.2, US-38.2, US-38.4, US-41.2.

## Sheets, not textures

| Step | What |
|---|---|
| Source | `assets/**/*.svg`, imported as **keep**: they ship as SVG, Godot makes no texture of its own |
| Raster | On first use, `ArtAtlas` rasters each SVG with Godot's ThorVG at `texels_per_u` (2 to 4, picked from the screen height: 3 on a 1080 px phone) |
| Pack | One sheet per family: `actors` (soldier, weapons, effects, pickups), `bedroom` (props) and `bedroom_back` (backdrop, at 0.75 density). Edges are extruded into the gaps, then mipmaps |
| Draw | Callers draw pieces in author px (8 per u) with `ArtAtlas.draw()`; a toy, its gun and its flash share one texture, so they batch |

Measured on hapl-aux: actors sheet 664 x 672 in about 30 ms, bedroom sheet 2572 x 2680 in about
200 ms, both at density 3.

## The soldier

| Part | How |
|---|---|
| Rig | `ToyRig` reads `rig.json`: parts, pivots, parents, z order. Forward kinematics in code |
| Arms | Two-bone IK to the weapon's `grip` (near hand) and `support` (far hand), the same maths as `art/tools/compose.py`. Off-hand guns take the far hand. `handless` floats the gun beside the body (US-11.5) |
| Aim | The gun angle is the fighter's aim exactly, whatever the lean; the grip swings about the chest |
| Poses | Stand and fly from `poses.json`; run is a cycle on distance travelled; jump, fall and crouch are set in `ToyAnimator` |
| Lean | T-17, from the ruleset (US-03.4): about the feet on the ground, the hips in the air |
| Acting | Recoil on every shot, a flinch away from the hit, faces: determined, cocky in flight or after a pop, hurt when hit, shocked near death or out of battery |
| Thrust | Flames from both nozzles along the push, light added on top, smoke puffs, a smoke ring on take-off (US-03.1) |
| Team | Greyscale battery layer tinted by `TeamPalette`, a pattern per team (plain, stripes, dots, chevrons), and `TeamOutline` around the toy. Free-for-all keeps the copper top (US-26.1, US-26.2) |
| Pop | Every part flies off from where it was and bounces on the terrain, the helmet highest; a snap at each joint, a burst and POP! (US-15.1) |
| Hitbox | The sim's T-18 shapes; the art never touches them (tested) |

## Effects

`FxField` holds world effects as plain data in two canvas items: shapes drawn as they are, and
light (`blend: add` in `fx.json`) added on top. Muzzle flashes, sparks on impact, hit flashes,
the frag blast (fireball, light, smoke, sparks), thrust smoke, the pop. `CombatView` draws
tracers (a warm core plus added light), rockets with exhaust, spinning grenades with a blinking
light, items on the floor as their own art, and spawn protection as a bubble.

## Performance (6 v 6 on the bedroom, `tools/shot/runs/art-perf-6v6.json`)

| What | Mean | Worst |
|---|---|---|
| Draw calls, world only (HUD hidden) | 15 | 32 |
| Draw calls, with the HUD | 127 | 208 |
| Canvas items | 564 | 912 |
| Toy views' script time per frame, 12 toys | 1.4 ms | |
| All art drawing callbacks per frame | under 1 ms | |

Frame time here comes from software GL (llvmpipe), so it says nothing about a phone; the
Android build is where to read it. Each toy's outline is a `CanvasGroup`: one offscreen pass
per toy, 12 in a full match. Bedroom sheet memory is about 27 MB plus mipmaps (RGBA8); VRAM
compression at load would cut it to a quarter.

## Under the bed and the desk

The kit draws the bed's foot post and the desk's right leg down to the floor, and its collision
did the same, which sealed the spaces under them with spawn points and a pickup inside.
`tools/make_bedroom.gd` lifts those two polygons 53 u off the floor (`FLOOR_GAPS`, the bed
rail's height, over a standing toy's 39.5 u), so toys walk in and out in front of the drawn leg.

## Tools

```sh
xvfb-run -a godot --path . --resolution 1600x900 -s tools/art/pose_sheet.gd -- out.png 3        # every rig state
xvfb-run -a godot --path . --resolution 2400x1000 -s tools/art/map_overview.gd -- res://maps/bedroom/bedroom.tscn out.png collision
tools/shot.sh tools/shot/runs/art-fight.json out/ --movie                                         # run, fly, shoot, pop
```
