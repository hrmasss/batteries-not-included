# Map format

A map is a Godot scene whose root is a `GameMap` node (`src/maps/game_map.gd`). Everything a
match needs from a map is a node in that scene, found by name and type. Maps are data: add a
scene, no code. Our maps are our own; only the classic's way of describing a map (points,
pools, bases) is reused, never a layout.

Units are world units `u` (1/64 of a tile; a toy is about 45 u tall). Positions are Godot's 2D
space: x right, **y down**. The standard view shows 640 × 360 u of map on a 16:9 screen at 1X.

## Layout

```
BedroomBlockout   GameMap    display_name, battery_full, item_gravity, bounds
├─ Backdrop       Node2D     anything drawn behind; no collision
├─ Terrain        Terrain    StaticBody2D; children are its solid shapes
│  ├─ Floor       CollisionShape2D (RectangleShape2D) or CollisionPolygon2D
│  └─ ...
├─ Spawns         Node2D
│  └─ Spawn1      SpawnPoint team
├─ Pickups        Node2D
│  └─ PickupBed   PickupPoint items, interval
└─ Bases          Node2D
   └─ BaseTeam0   TeamBase team, kind
```

## Root properties (`GameMap`)

| Property | Type | Meaning |
|---|---|---|
| `display_name` | text | Shown in menus |
| `battery_full` | number | Full battery on this map (T-20). `-1` keeps the ruleset's. The classic's two ice maps use 15 |
| `item_gravity` | number | Gravity factor for loose items: grenades, dropped guns. Never for toys. The classic's moon map uses 0 |
| `bounds` | Rect2 | Leaving this box hurts (T-34). Also the camera's limits |

A match's battery size comes from, in order: the `battery_size` modifier, the map's
`battery_full`, the ruleset's `battery_full` (US-02.9).

## Terrain

`Terrain` nodes are solid: toys stand on them, bullets stop at them. Their child
`CollisionShape2D` (rectangles) and `CollisionPolygon2D` (any convex or concave outline) nodes
are the solids. A map may hold several `Terrain` nodes. Contact bounce and friction come from
the ruleset (`surfaces.cfg`), not the map. Until real art lands, `Terrain` draws its shapes as
dark blockout fills; art maps turn `draw_shapes` off and draw their own.

Terrain sits on physics layer 1. Toys sit on layer 2 and collide only with layer 1, so toys pass
through each other, as in the classic.

## Spawn points (`SpawnPoint`)

| Property | Meaning |
|---|---|
| position | Where the toy's feet go |
| `team` | Team that may spawn here in team modes; `-1` for any team and free-for-all |

Spawn choice (T-71) scores points by distance from enemies; give a map at least twice as many
points as the teams it supports, spread out.

## Pickup points (`PickupPoint`)

| Property | Meaning |
|---|---|
| position | Where the item appears |
| `items` | Item ids that may appear here; one is drawn at random each time (T-76). Weapons by their id in the weapon table, plus `frag`, `health_pack`, `battery_pack` |
| `interval` | Own respawn interval in seconds; `-1` uses the match's setting (T-76) |

## Team bases (`TeamBase`)

| Property | Meaning |
|---|---|
| position | The base |
| `team` | Owning team, from 0 |
| `kind` | `flag` (capture the flag) or `bomb_site` (plant the bomb); R2 |

## Art maps

`maps/bedroom/` is built from the art lab's kit (`assets/maps/bedroom/kit.json`) by
`tools/make_bedroom.gd`: each prop is a `KitProp` node that draws its kit piece, and its
collision polygons come from the same kit entry, so the terrain is what is drawn. Kit
"platform" shapes are solid like the rest (the sim has no one-way terrain). The wall, window
and posters sit in a `Parallax2D` that scrolls a little slower than play; the floor and skirting
are `KitTiles`. `Terrain.draw_shapes` is off. The bedroom is the default map; the blockout stays
for tests and old shot runs.

```sh
godot --headless --path . -s tools/make_bedroom.gd    # rebuild maps/bedroom/bedroom.tscn
```

## Making a map

1. Open the Godot editor, create a scene with a `GameMap` root, add the four holder nodes and a
   `Terrain`, then draw rectangles and polygons as its children.
2. Or generate one from a script, as `tools/make_blockout.gd` does for the bedroom blockout:
   `godot --headless --path . -s tools/make_blockout.gd`.
3. Check it: `tests/view/test_game_view.gd` has a map check (spawn points inside bounds, pickup
   lists not empty) to copy for a new map.
