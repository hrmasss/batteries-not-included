class_name MatchConfig
extends RefCounted
## What a host picks before a match (US-19.1, US-36.1): mode, teams, map, bots, bot skill,
## time, kill limit, pickups and Batteries Included. Starts from the ruleset's defaults; the
## match server applies it to a copy of the ruleset, so every toy plays the same rules.

enum Mode { FFA, TDM }

## A match needs two sides: two players, or two teams. A rule of the game, not tuning.
const SIDES := 2
const DEFAULT_MAP := "res://maps/bedroom_blockout/bedroom_blockout.tscn"

var mode: Mode = Mode.FFA
## Teams in team deathmatch (T-78).
var teams: int = SIDES
var map_path: String = DEFAULT_MAP
## Bots in bootcamp, 1 to players_max − 1 (US-36.1).
var bots: int = 1
var skill: StringName = &""
## Match length, s (T-72).
var length: float = 0.0
## T-73: off by default.
var kill_limit_on: bool = false
var kill_limit: int = 0
## Pickup respawn interval, s; 0 turns map pickups off (T-76).
var pickup_interval: float = 0.0
var batteries_included: bool = false
## Seeds every random roll of the match, bots included.
var seed_value: int = 0


## A fresh config from the ruleset's defaults.
static func defaults(rules: Ruleset) -> MatchConfig:
	var c := MatchConfig.new()
	c.teams = int(rules.teams_min)
	c.bots = int(rules.players_default) - 1
	c.skill = rules.bots.default_id() if rules.bots != null else &""
	c.length = rules.match_length
	c.kill_limit_on = rules.kill_limit_on
	c.kill_limit = int(rules.kill_limit)
	c.pickup_interval = rules.pickup_interval
	c.batteries_included = rules.batteries_included
	return c


func copy() -> MatchConfig:
	var c := MatchConfig.new()
	c.read(to_dict())
	return c


## Brings every choice inside what the ruleset allows.
func clamp_to(rules: Ruleset) -> void:
	teams = clampi(teams, int(rules.teams_min), int(rules.teams_max))
	bots = clampi(bots, 1, int(rules.players_max) - 1)
	length = clampf(length, rules.match_length_min, rules.match_length_max)
	kill_limit = maxi(kill_limit, 1)
	pickup_interval = maxf(pickup_interval, 0.0)
	if rules.bots != null and not rules.bots.has(skill):
		skill = rules.bots.default_id()


## A copy of `rules` with this match's host choices in it (US-19.2).
func apply(rules: Ruleset) -> Ruleset:
	var r := rules.copy()
	r.pickup_interval = pickup_interval
	r.batteries_included = batteries_included
	return r


func is_teams() -> bool:
	return mode == Mode.TDM


## The team of the toy in seat `seat` (0 is the player): round robin over the teams, so sides
## stay even. Free-for-all has no teams.
func team_of_seat(seat: int) -> int:
	if not is_teams():
		return Fighter.NO_TEAM
	return seat % teams + 1


func to_dict() -> Dictionary:
	return {
		"mode": int(mode), "teams": teams, "map": map_path, "bots": bots, "skill": String(skill),
		"length": length, "kill_limit_on": kill_limit_on, "kill_limit": kill_limit,
		"pickup_interval": pickup_interval, "batteries_included": batteries_included, "seed": seed_value,
	}


func read(d: Dictionary) -> void:
	mode = clampi(int(d.get("mode", mode)), 0, Mode.size() - 1) as Mode
	teams = int(d.get("teams", teams))
	map_path = str(d.get("map", map_path))
	bots = int(d.get("bots", bots))
	skill = StringName(str(d.get("skill", skill)))
	length = float(d.get("length", length))
	kill_limit_on = bool(d.get("kill_limit_on", kill_limit_on))
	kill_limit = int(d.get("kill_limit", kill_limit))
	pickup_interval = float(d.get("pickup_interval", pickup_interval))
	batteries_included = bool(d.get("batteries_included", batteries_included))
	seed_value = int(d.get("seed", seed_value))
