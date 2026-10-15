# Art sources

The game's art is drawn in code: small Python scripts write the SVGs in `assets/`. Python 3
standard library only for the generators; previews also need `rsvg-convert` and Pillow, and the
Godot checks need Godot 4.7 and `xvfb-run`.

```sh
# regenerate every asset
python3 art/src/soldier.py && python3 art/src/weapons.py && python3 art/src/fx.py && python3 art/src/bedroom.py

# checks: Godot-safe SVG features, json cross-references, Godot raster vs librsvg per file
python3 art/tools/check.py

# previews: contact sheets, then the mock battle frame rendered by librsvg and inside Godot
python3 art/tools/sheets.py
art/tools/godot_frame.sh
```

| Path | What |
|---|---|
| `lib/bni_svg.py` | The drawing kit: smooth shapes, gradients, and `molded()`, the shading every playable thing shares (rim light, shadow band, lit body, gloss, one outline weight) |
| `src/` | One generator per asset family |
| `tools/compose.py` | Places parts by `rig.json`, poses with two-bone arm IK, records each placement |
| `tools/frame.py` | The 1280x720 mock battle frame; glow layers added the way the engine adds them |
| `tools/godot_frame.gd` | Rebuilds that frame in Godot from the same assets: ThorVG rasters, additive glow, `CanvasGroup` team outline |
| `tools/sheets.py` | Contact sheets in `previews/` |
| `tools/check.py` | The asset checks |
| `previews/` | Contact sheets and the two frame renders |

## Art lab result (2026-10-15)

Question: can code-drawn vector art carry the look? Scored against the reference sheet in the
private workspace (`docs/art/`), 1 to 5.

| Area | Score | Against | Gap |
|---|---|---|---|
| Soldier | 3 | refs 01, 09, 10 | Cel-shaded, not painted: less volume and light. Faces read big and at 2x; at 1x (90 px) the expression is a blur |
| Weapons | 4 | ref 02 | Close to the reference. Relative sizes are set by the soldier's short arms |
| Effects | 4 | refs 03, 11, 14 | Glow works on pale and dark ground. The pop is a still layout until the game animates it |
| Bedroom kit | 3 | refs 16, 18 | Clear and saturated against a pale backdrop, so you know what you can stand on. Flat light; real furniture scale makes big props read as walls, so toy-sized clutter (blocks, books) carries the mid-height cover |
| Battle frame | 3 | ref 05 | Readable and staged. Missing the painted light and depth; toys look smaller because ours uses the spec camera (toy an eighth of the screen) and ref 05 is closer |

Verdict: vector carries the toys, weapons, props and effects at game size. The gap is light
and atmosphere, which lives mostly in the backdrop. A painted raster backdrop plate behind the
vector props is the cheapest way to close it, and keeps the playable pieces crisp.
