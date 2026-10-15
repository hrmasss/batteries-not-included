class_name MatchRunner
extends RefCounted
## One match on the match server, start to results: the sim and its fighting, the players and
## the bots, the scoreboard and the end rules. Each tick it asks every bot for its intent,
## steps the sim with those and the players' intents, keeps score and checks the end. Once the
## match is over it stops stepping. The app's view and headless tests drive it the same way.

signal ended(result: MatchRules.Result)

var sim: MatchSim
var combat: CombatSim
var config: MatchConfig
var scores := Scoreboard.new()
var rules: MatchRules
var bots: Array[Bot] = []
var nav: NavGrid = null
## Toys run by people on this match server, by id.
var humans: Array[int] = []


## Runs a match on `match_sim`, whose combat must have started.
func _init(match_sim: MatchSim, match_config: MatchConfig) -> void:
	sim = match_sim
	combat = match_sim.combat
	config = match_config
	rules = MatchRules.new(config, scores)
	combat.team_spawns = config.is_teams()
	combat.event.connect(scores.on_event)


## Seats a person's fighter.
func add_human(f: Fighter, player_name: String) -> void:
	humans.append(f.id())
	scores.add(f.id(), player_name, f.team, false)


## Puts a bot in charge of `f` at skill `level` (US-36.3).
func add_bot(f: Fighter, player_name: String, level: StringName = &"") -> Bot:
	var table := sim.rules.bots
	var id := level if table.has(level) else config.skill
	if not table.has(id):
		id = table.default_id()
	var skill := table.get_level(id)
	if nav == null:
		nav = NavGrid.build(sim, skill.nav_cell, skill.air_cost)
	var b := Bot.new(f, skill, sim, nav, config.seed_value * sim.rules.players_max + f.id())
	bots.append(b)
	scores.add(f.id(), player_name, f.team, true)
	return b


## Spawns the config's bots at fair spawn points, seated after the player (US-36.1).
## Returns the new fighters, for a view to draw.
func spawn_bots(names: PackedStringArray = []) -> Array[Fighter]:
	var out: Array[Fighter] = []
	for k in config.bots:
		var seat := humans.size() + k
		var f := combat.spawn(config.team_of_seat(seat))
		var n := names[k] if k < names.size() else "Bot %d" % (k + 1)
		add_bot(f, n)
		out.append(f)
	return out


## A toy leaves the match (US-17.6, US-18.3 end the match when too few are left).
func leave(toy_id: int) -> void:
	for b in bots:
		if b.id() == toy_id:
			bots.erase(b)
			break
	humans.erase(toy_id)
	scores.remove(toy_id)
	combat.leave(toy_id)


func is_over() -> bool:
	return rules.over


func time() -> float:
	return combat.time


func time_left() -> float:
	return rules.time_left(combat.time)


## One tick. `intents` holds the people's intents by toy id; bots add their own.
func step(intents: Dictionary = {}) -> void:
	if rules.over:
		return
	var all := intents.duplicate()
	for b in bots:
		all[b.id()] = b.intent(SimClock.TICK)
	sim.step(all)
	if rules.check(combat.time):
		ended.emit(rules.result)


## Runs until the match ends or `max_ticks` pass. For tests and tools.
func run_to_end(max_ticks: int, intents: Dictionary = {}) -> void:
	for k in max_ticks:
		if rules.over:
			return
		step(intents)
