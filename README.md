# Batteries Not Included

A 2D jetpack shooter where toys fight on giant household maps. Dual-stick flying, aiming
and shooting. LAN multiplayer for up to 12 players over Wi-Fi or a phone hotspot, no account
needed.

Built with Godot 4.7, typed GDScript, the Compatibility renderer. Android first.

**Status:** the first playable. Bootcamp: free-for-all or team deathmatch against 1 to 11 bots
on a blockout bedroom, with five short lessons. LAN play comes next.

## Run it

You need [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/).

```sh
godot --path .            # play
godot --path . --editor   # open the editor
```

| Input | Keyboard and mouse | Gamepad |
|---|---|---|
| Move stick: walk, jump (up), crouch (down), fly (keep pushing) | WASD or arrows | Left stick |
| Aim | Mouse | Right stick |
| Fire | Left mouse button | Right trigger |
| Grenade, melee, reload | G, F, R | LB, B, X |
| Switch weapon, pick up, zoom, grenade type | Q, E, Z, X | Y, A, right stick click, D-pad down |
| Debug overlay, hitboxes, respawn | F1, F2, F5 | Back (respawn) |
| Spawn a dummy target: enemy, teammate | F6, F7 | |

Jump, keep pushing up, and the jetpack takes over half a second later. Then the toy flies
wherever the stick points. The battery drains faster pointing up and refills a second after
you stop.

## Test

```sh
GODOT=/path/to/godot tools/test.sh                    # every test, headless
GODOT=/path/to/godot tools/test.sh -gselect=test_us02 # one file
```

Tests use [GUT](https://github.com/bitwes/Gut) (vendored in `addons/gut`). Test names carry
the criterion they prove (`test_us02_8_full_up_flight_time` proves US-02.8). CI runs the same
script on every push and pull request.

## Screenshots and clips

```sh
GODOT=/path/to/godot tools/shot.sh tools/shot/runs/foundation.json out/ --movie
```

Plays a scripted run (`tools/shot/runs/*.json`) under a virtual display, saves a PNG at each
named moment and, with `--movie`, an mp4 of the run. Needs `xvfb-run` and `ffmpeg`.

## Tune

Every movement and battery number lives in `data/rulesets/standard/`, one file per group, each
value next to its tuning name (`T-1` and so on). Change a value, run the game, feel it. The
game refuses a ruleset with a missing or out-of-range value and names it.

## Layout

| Path | What |
|---|---|
| `src/sim/` | The match server's simulation: rules, toys, the fixed clock, match rules and bots ([match and bots](docs/match-and-bots.md)). Reads no input, draws nothing |
| `src/app/`, `src/lessons/` | The app's screens: menu, bootcamp, match, results, lessons, settings |
| `src/view/` | The app: input, drawing, camera, debug overlay |
| `src/rules/` | Ruleset schema, values and loader |
| `src/maps/`, `maps/` | Map node types and the maps ([format](docs/map-format.md)) |
| `data/rulesets/` | Rulesets |
| `tests/` | Headless tests |
| `tools/` | Test, screenshot and map scripts |
| `docs/` | [Architecture](docs/architecture.md), [map format](docs/map-format.md) |

## License

Code is under the GNU General Public License v3.0 or later, see [LICENSE](LICENSE). Art and
sound, as they land, are under CC BY-SA 4.0. See [CONTRIBUTING](CONTRIBUTING.md).
