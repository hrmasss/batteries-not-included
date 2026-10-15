class_name CombatStub
extends RefCounted
## Stand-in for the combat task's numbers until it merges: teams and names, the held weapon,
## ammo, grenades, the clock, scores, kill feed lines, pops and hits. Values are set by whoever
## drives a scene (a demo, a test, a screenshot run). No rule lives here: it only holds what it
## is told and ages it.
##
## When combat lands, `SimHudSource` reads these from the sim instead and this class goes.

## How long a kill feed line stays, seconds. Ours: the classic's message layer was not read.
const FEED_LIFE := 6.0
const FEED_MAX := 4
## How long a hit marker stays, seconds.
const HIT_LIFE := 1.0

var teams: Dictionary = {}
var names: Dictionary = {}
var team_mode: bool = true
var weapon_name: String = "Pistol"
var weapon_key: StringName = &"pistol"
var magazine: int = 15
var reserve: int = 45
var reloading: bool = false
var grenades: Array[HudState.Grenade] = []
var clock: float = 390.0
var clock_running: bool = true
var scores: Array[HudState.Score] = []
var feed: Array[HudState.FeedLine] = []
var popped: bool = false
var respawn_in: float = 0.0
var popped_by: String = ""
var popped_by_team: int = -1
var popped_with: String = ""
var protected_for: float = 0.0
var can_pick_up: bool = false

var _fired: Dictionary = {}
var _hits: Array[Vector2] = []


func _init() -> void:
	var frag := HudState.Grenade.new()
	frag.kind = &"frag"
	frag.count = 2
	grenades.append(frag)


func team_of(toy_id: int) -> int:
	return teams.get(toy_id, -1)


func name_of(toy_id: int) -> String:
	return names.get(toy_id, "Toy %d" % toy_id)


## A toy fired: its radar arrow lights up (T-87).
func mark_fired(toy_id: int) -> void:
	_fired[toy_id] = true


func take_fired(toy_id: int) -> bool:
	return _fired.erase(toy_id)


## A hit landed on this player from `from` (world position).
func hit_from(from: Vector2) -> void:
	_hits.append(from)


func pop_line(killer: String, killer_team: int, victim: String, victim_team: int, weapon: String) -> void:
	var l := HudState.FeedLine.new()
	l.killer = killer
	l.killer_team = killer_team
	l.victim = victim
	l.victim_team = victim_team
	l.weapon = weapon
	l.suicide = killer == victim or killer == ""
	feed.push_front(l)
	if feed.size() > FEED_MAX:
		feed.resize(FEED_MAX)


func fill(into: HudState, dt: float) -> void:
	if clock_running and clock > 0.0:
		clock = maxf(0.0, clock - dt)
	if popped:
		respawn_in = maxf(0.0, respawn_in - dt)
	protected_for = maxf(0.0, protected_for - dt)
	for l in feed:
		l.age += dt
	feed = feed.filter(func(l: HudState.FeedLine) -> bool: return l.age < FEED_LIFE)
	into.weapon_name = weapon_name
	into.magazine = magazine
	into.reserve = reserve
	into.ammo_infinite = into.batteries_included
	into.reloading = reloading
	into.grenades = grenades
	into.clock = clock
	into.scores = scores
	into.feed = feed
	into.popped = popped
	into.respawn_in = respawn_in
	into.popped_by = popped_by
	into.popped_by_team = popped_by_team
	into.popped_with = popped_with
	into.protected_for = protected_for
	into.can_pick_up = can_pick_up
	into.team_mode = team_mode
	into.hits_from = _hits.duplicate()
	_hits.clear()
