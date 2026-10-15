# Combat

Fighting on the match server: weapons, bullets, melee, grenades, blasts, health, pops, kill
credit, respawns, spawn protection and pickups. Specs: workspace `docs/specs/01_world.md`
("Weapons and damage" to "Spawning"), `04_tuning.md` T-24, T-30 to T-77, stories US-05 to
US-16, US-22.

## Where things live

| What | Where |
|---|---|
| Fighting rules, one tick at a time | `src/sim/combat/combat_sim.gd` (`CombatSim`) |
| A toy's fighting state: team, weapons, grenades, timers, score | `src/sim/combat/fighter.gd` |
| One weapon in the match, carried or on the floor, with its ammo | `src/sim/combat/weapon_item.gd` |
| The weapon table (T-50) and spawn kit, with its checks | `src/sim/combat/weapon_table.gd`, `weapon_def.gd` |
| Weapon rows | `data/rulesets/standard/weapons.cfg` |
| Health, guns, throwables, match values | `health.cfg`, `guns.cfg`, `throwables.cfg`, `match.cfg` in the ruleset |
| Placeholder drawing | `src/view/combat_view.gd` (`CombatView`) |

## One tick

`MatchSim.step` moves every live toy, then calls `CombatSim.step` with the same sanitized intents:

| Order | What happens |
|---|---|
| 1 | Each living fighter acts on its intent: switch, reload, zoom, grenade switch, pick up, throw, melee (on the press), fire (while held) |
| 2 | Bullets, rockets and grenades move; hits, blasts and pops resolve |
| 3 | Protection runs down, health packs flow, regen, battery pack, out of bounds |
| 4 | Floor items fall and age; touch pickups; pickup points spawn |
| 5 | Popped fighters count down and respawn |

Every change of fighting state goes out as an event (`CombatSim.event`): `shot`, `hit`,
`blocked`, `impact`, `swing`, `throw`, `blast`, `pop`, `spawn`, `drop`, `pickup`,
`item_spawn`, `expire`, `switch`, `protection_end`. The view draws from them; the network will
send them.

## Rules worth knowing

- **Damage goes through `CombatSim.hurt`, and only there.** Spawn protection blocks every kind.
- **Who gets hurt.** Bullets, rockets' direct hits and melee skip the shooter and its teammates.
  Blasts hurt everyone in the radius, the thrower included. Team 0 means no team: everyone is an
  enemy.
- **Kill credit.** The last hit's attacker; with no attacker (out of bounds), the last toy that
  hurt it. Own pop: a suicide. Popping a teammate: a team kill and a suicide, no kill.
- **Random rolls** (spread, pickup draws, spawn picks) come from one generator the match
  seeds (`MatchSim.start_combat(seed)`), so a run replays exactly.
- **Weapons are data.** A new row in `weapons.cfg` of an existing kind (`bullet`, `rocket`,
  `melee`) is a new weapon. Burst and spin-up are fields. Beam, flame and saw come in R2.

## Debug keys

F6 spawns a still enemy dummy at a fair spawn point, F7 a teammate. Shot runs for combat are in
`tools/shot/runs/combat-*.json`; they can place dummies (optionally firing) and items.
