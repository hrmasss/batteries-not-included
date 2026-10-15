class_name SimHudSource
extends HudSource
## Reads one player's HUD numbers from the match: health and battery from the toy; weapon, ammo,
## grenades, scores, pops, protection and pick-up from the fighter (`CombatSim`); the kill feed,
## hits and radar alerts from combat events.
##
## Not in the sim yet, so set by whoever runs the match: player names (`names`, else "Toy N")
## and the match clock (`clock`, negative hides it). The match loop owns both when it lands.

var sim: MatchSim
var me_id: int = 0
## Toy id to player name.
var names: Dictionary = {}
## Seconds left in the match, counting down while `clock_running`; negative hides the clock.
var clock: float = -1.0
var clock_running: bool = true

var _feed: Array[HudState.FeedLine] = []
var _hits: Array[Vector2] = []
var _fired: Dictionary = {}
var _combat: CombatSim = null


func _init(match_sim: MatchSim, toy_id: int) -> void:
	sim = match_sim
	me_id = toy_id
	_watch()


func name_of(toy_id: int) -> String:
	return names.get(toy_id, "Toy %d" % toy_id)


## The HUD's team index for a fighter: -1 with no team, else 0 for the first team.
static func hud_team(f: Fighter) -> int:
	return -1 if f == null or f.team == Fighter.NO_TEAM else f.team - 1


func read(into: HudState, dt: float) -> void:
	_watch()
	var me := sim.toy(me_id)
	if me != null:
		into.health = me.health
		into.health_max = sim.rules.max_health
		into.battery = me.battery
		into.battery_max = me.battery_max
		into.my_position = me.position
	into.batteries_included = sim.rules.batteries_included
	if clock_running and clock > 0.0:
		clock = maxf(0.0, clock - dt)
	into.clock = clock
	var f := _combat.fighter(me_id) if _combat != null else null
	into.my_team = hud_team(f)
	into.team_mode = f != null and f.team != Fighter.NO_TEAM
	_read_fighter(into, f)
	into.scores = _scores(f)
	into.contacts.clear()
	for t in sim.toys:
		if t.toy_id == me_id:
			continue
		var c := HudState.Contact.new()
		c.toy_id = t.toy_id
		var other := _combat.fighter(t.toy_id) if _combat != null else null
		c.team = hud_team(other)
		c.alive = t.active
		c.position = t.position
		c.velocity = t.velocity
		c.fired = _fired.erase(t.toy_id)
		c.name = name_of(t.toy_id)
		into.contacts.append(c)
	for l in _feed:
		l.age += dt
	_feed = _feed.filter(func(l: HudState.FeedLine) -> bool: return l.age < HudState.FEED_LIFE)
	into.feed = _feed
	into.hits_from = _hits.duplicate()
	_hits.clear()


func _read_fighter(into: HudState, f: Fighter) -> void:
	var w := f.main_weapon() if f != null else null
	into.weapon_name = w.def.display_name if w != null else "Bare hands"
	into.magazine = w.mag if w != null else 0
	into.reserve = w.reserve if w != null else 0
	into.ammo_infinite = into.batteries_included or w == null
	into.reloading = w != null and w.reloading()
	var nades: Array[HudState.Grenade] = []
	if f != null:
		# The selected type first (US-12.4), then the rest in a steady order.
		var kinds: Array = f.grenades.keys()
		kinds.sort()
		kinds.erase(f.grenade_type)
		if f.grenades.has(f.grenade_type):
			kinds.push_front(f.grenade_type)
		for k: StringName in kinds:
			var g := HudState.Grenade.new()
			g.kind = k
			g.count = int(f.grenades[k])
			nades.append(g)
	into.grenades = nades
	into.popped = f != null and not f.alive
	into.respawn_in = maxf(0.0, f.respawn_left) if into.popped else 0.0
	if into.popped:
		var killer := _combat.fighter(f.popped_by)
		into.popped_by = "" if killer == null else ("yourself" if killer == f else name_of(f.popped_by))
		into.popped_by_team = hud_team(killer)
		into.popped_with = _weapon_name(f.popped_with)
	into.protected_for = maxf(0.0, f.protect_left) if f != null else 0.0
	into.can_pick_up = f != null and f.alive and f.offer >= 0


## Team mode: each team's kills. Free-for-all: my kills and the leader's (US-25).
func _scores(f: Fighter) -> Array[HudState.Score]:
	var out: Array[HudState.Score] = []
	if _combat == null or f == null:
		return out
	if f.team != Fighter.NO_TEAM:
		var by_team := {}
		for o in _combat.fighters:
			if o.team != Fighter.NO_TEAM:
				by_team[o.team] = int(by_team.get(o.team, 0)) + o.kills
		var teams: Array = by_team.keys()
		teams.sort()
		for t: int in teams:
			var s := HudState.Score.new()
			s.team = t - 1
			s.kills = by_team[t]
			s.mine = t == f.team
			out.append(s)
		return out
	var mine := HudState.Score.new()
	mine.kills = f.kills
	mine.mine = true
	mine.name = name_of(f.id())
	out.append(mine)
	var leader: Fighter = null
	for o in _combat.fighters:
		if o != f and (leader == null or o.kills > leader.kills):
			leader = o
	if leader != null:
		var s := HudState.Score.new()
		s.kills = leader.kills
		s.name = name_of(leader.id())
		out.append(s)
	return out


func _watch() -> void:
	if _combat != null or sim == null or sim.combat == null:
		return
	_combat = sim.combat
	_combat.event.connect(_on_event)


func _on_event(e: Dictionary) -> void:
	match e.type:
		&"shot", &"throw":
			# T-87: a toy that fired lights its radar arrow.
			_fired[e.toy] = true
		&"hit":
			if e.toy == me_id:
				var from := _combat.fighter(int(e.attacker))
				if from != null and from.id() != me_id:
					_hits.append(from.toy.position)
		&"pop":
			_pop_line(e)


func _pop_line(e: Dictionary) -> void:
	var victim := _combat.fighter(int(e.toy))
	var killer := _combat.fighter(int(e.killer))
	var l := HudState.FeedLine.new()
	l.victim = name_of(int(e.toy))
	l.victim_team = hud_team(victim)
	l.suicide = killer == null or killer == victim
	l.killer = "" if killer == null else name_of(killer.id())
	l.killer_team = hud_team(killer)
	l.weapon = _weapon_name(e.weapon)
	_feed.push_front(l)
	if _feed.size() > HudState.FEED_MAX:
		_feed.resize(HudState.FEED_MAX)


## What popped someone, in words for the respawn panel: "the Uzi", "a frag", "bare hands".
func _weapon_name(id: StringName) -> String:
	match id:
		&"":
			return ""
		CombatSim.BARE_HANDS:
			return "bare hands"
		CombatSim.OUT_OF_BOUNDS:
			return "the edge of the map"
		&"frag":
			return "a frag"
	var d := sim.rules.weapons.get_def(id) if sim.rules.weapons != null else null
	return "the %s" % d.display_name if d != null else String(id).replace("_", " ")
