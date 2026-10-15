# Match rules, bots and the app loop

The match from start to results to rematch, the bots that fill it offline, and the screens
around it. Specs: workspace `docs/specs/01_world.md` ("A match", "Modes", "Spawning"),
`04_tuning.md` T-70 to T-78 and T-95 to T-98, stories US-17 to US-20, US-35, US-36.

## Where things live

| What | Where |
|---|---|
| A host's choices: mode, teams, map, bots, skill, time, kill limit, pickups, Batteries Included | `src/sim/match/match_config.gd` (`MatchConfig`) |
| Kills, deaths, suicides, team kills, damage, streaks, team scores, ranking | `src/sim/match/scoreboard.gd` (`Scoreboard`) |
| When a match ends and who won | `src/sim/match/match_rules.gd` (`MatchRules`) |
| One match on the match server: bots plus players, scores, end | `src/sim/match/match_runner.gd` (`MatchRunner`) |
| A bot's brain | `src/sim/bots/bot.gd` (`Bot`) |
| Bot skill levels and brain values | `data/rulesets/standard/bots.cfg`, read by `src/sim/bots/bot_skills.gd` |
| Where a toy can go, for bots | `src/sim/bots/nav_grid.gd` (`NavGrid`, on Godot's `AStarGrid2D`) |
| Match values (T-72 to T-78) | `data/rulesets/standard/match.cfg` |
| Lessons | `src/lessons/lesson_runner.gd` (`LessonRunner`) |
| Screens: menu, bootcamp setup, match, results, lessons, settings | `src/app/` |

## One tick

`MatchRunner.step` runs in place of `MatchSim.step` when a match has rules and bots:

| Order | What happens |
|---|---|
| 1 | Each bot reads the match and returns an `InputIntent`, like a thumb on a touch screen |
| 2 | The sim steps with the bots' and the players' intents (movement, then combat) |
| 3 | The scoreboard has counted this tick's combat events (`hit`, `pop`) as they fired |
| 4 | `MatchRules.check`: time up (T-72), kill limit (T-73, off by default), one player or one team left |
| 5 | On the end: `ended(result)` with the winner or a tie, the ranked rows and the best player; no more ticks |

## Rules worth knowing

- **Score.** A kill: the killer's kills and streak go up. A suicide: the victim's suicides. A team
  kill: the killer's team kills and suicides, no kill. Every pop is a death. Damage counts on
  enemies only, the hit's full amount. A team's score is its players' kills.
- **Winner.** Free-for-all: most kills, equal tops tie. Team deathmatch: top team score, equal
  tops tie. Best player: most kills, then fewest deaths, then most damage.
- **Seats.** The player is seat 0, bots after; in team deathmatch seats go round robin over the
  teams, so sides stay even. Rematch keeps the setup and the seats and rolls a new seed.
- **Bots never cheat** (T-98). A bot only returns intents; nothing under `src/sim/bots` writes
  match state (a test checks it). Its toy has the same body, kit, battery and ammo.

## How a bot plays

| Part | Rule |
|---|---|
| Sight (T-95) | Enemies within its level's sight, with a clear line from 20 u above the body. It reacts to one only after it has been in sight for its reaction time |
| Aim (T-96) | Turns its aim by (turn_rate + turn_gain × gap) per second, the classic's 1 + gap/20 degrees per 60 Hz step on easy, and stops inside the dead zone. A small wobble on top; harder levels lead moving targets |
| Fire (T-97) | First wait, first burst, then waits and bursts at random. Fires only with the aim inside its cone and the target in range |
| Frags and melee | Frags at middle range, aimed to land short and roll on, never with a teammate near the target. Melee up close |
| Moving | Fights at a distance that suits the held gun, sliding side to side. Takes pickups it can see when they help. Falls back to a place out of sight when hurt. Chases where it last saw an enemy, else wanders the map's points |
| Getting there | Straight when the way is clear, else along a grid path. Walks on floors, jumps walls, flies where it must, slows down near the goal |
| Battery | Below its low mark it stops flying until the battery is back to its resume mark |
| Stuck | Moved less than 15 u in 3 s (the classic's test) while going somewhere: a new place to go, and a push up and sideways |

Skill levels are rows in `bots.cfg`: easy is the classic's drone exactly; normal and hard see
farther, react sooner, turn faster and wait less between bursts. A new level is a new section.

## Lessons

Five short lessons, in order: move, fly, aim and fire, pick up and swap, grenades. Each step
names one thing to do and the control to use; it moves on only when the match shows the player
did it (US-35.2). The screen points an arrow at that control on the touch layout. Any lesson can
be skipped or replayed; the first launch offers them, never forces them.

## Tools

```sh
godot --headless --path . -s tools/sim/bot_match.gd -- 11 390 ffa normal 3   # a full bot match, scores and movement
tools/app_shot.sh tools/shot/plans/clip-ffa.json out/ --movie                 # the app from menu to rematch, recorded
EMULATOR_LOCK=lock xvfb-run -a tools/android-bootcamp.sh bni-debug.apk out/  # the same in the Android emulator
```

Proof plans set `autoplay`: a normal bot plays the player's toy. The app has the same switch as
`[debug] autoplay=true` in `user://app.cfg`; no screen offers it.
