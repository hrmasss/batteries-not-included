class_name GameView
extends Node2D
## The app side of a match on one device: runs the match server's sim on the fixed clock,
## feeds it the local player's intent each tick, and draws it (rules A1 to A3). With LAN play
## the sim moves to the host and this view sends intents instead; nothing here decides a rule.

## The map to play. Default: the bedroom (maps/bedroom); the blockout stays for tests.
@export var map_scene: PackedScene
## The ruleset directory to run.
@export var ruleset_dir: String = RulesetLoader.STANDARD_DIR
@export var show_overlay: bool = true
@export var show_hitboxes: bool = false
## Which of the map's spawn points the player starts at.
@export var spawn_index: int = 0
## The player's team; 0 is no team (free-for-all).
@export var player_team: int = Fighter.NO_TEAM
## Seeds every random roll of the match (spread, pickups, spawns).
@export var combat_seed: int = 0

var sim: MatchSim
var clock := SimClock.new()
var player: SimToy
var source: InputSource
var camera: GameCamera
var overlay: DebugOverlay
## HUD and touch controls (US-23, US-25).
var player_hud: PlayerHud
var toy_views: Array[ToyView] = []
var combat: CombatSim
var me: Fighter
var combat_view: CombatView
## Fixed intents for other toys by toy id, for test scenes and scripted runs.
var extra_intents: Dictionary = {}

var _last_frame: float = 0.0


func _ready() -> void:
	InputActions.ensure()
	var loaded := RulesetLoader.load_dir(ruleset_dir)
	if not loaded.ok():
		_refuse(loaded.errors)
		return
	if map_scene == null:
		map_scene = load("res://maps/bedroom/bedroom.tscn")
	sim = MatchSim.new()
	sim.name = "MatchSim"
	sim.setup(loaded.ruleset, map_scene.instantiate())
	add_child(sim)
	player = sim.spawn_toy(spawn_index)
	combat = sim.start_combat(combat_seed)
	me = combat.join(player, player_team)
	for t in sim.toys:
		_add_toy_view(t)
	combat_view = CombatView.new(combat, me)
	add_child(combat_view)
	camera = GameCamera.new(sim.rules)
	add_child(camera)
	camera.make_current()
	var b := sim.map.bounds
	camera.limit_left = int(b.position.x)
	camera.limit_top = int(b.position.y)
	camera.limit_right = int(b.end.x)
	camera.limit_bottom = int(b.end.y)
	player_hud = PlayerHud.new()
	player_hud.name = "PlayerHud"
	add_child(player_hud)
	player_hud.setup(sim, player.toy_id, camera)
	overlay = DebugOverlay.new()
	overlay.visible = show_overlay
	add_child(overlay)
	if source == null:
		source = TouchInput.new()
	if source is TouchInput:
		(source as TouchInput).controls = player_hud.touch
	if source.get_parent() == null:
		add_child(source)
	_sync_views(0.0)


func _process(delta: float) -> void:
	if sim == null:
		return
	_last_frame = delta
	for i in clock.advance(delta):
		var intent := source.intent_for(self, sim.tick)
		player_hud.on_intent(intent)
		var intents := extra_intents.duplicate()
		intents[player.toy_id] = intent
		sim.step(intents)
	_sync_views(delta)


func _sync_views(delta: float) -> void:
	var alpha := clock.alpha()
	for v in toy_views:
		v.show_hitboxes = show_hitboxes
		v.visible = v.toy.active
		v.sync(alpha, delta)
	combat_view.sync(delta)
	camera.follow(player_view_position(), delta)
	player_hud.frame()
	overlay.show_toy(player, sim.tick, _last_frame, show_hitboxes)


## Where the player's toy is drawn this frame.
func player_view_position() -> Vector2:
	return player.prev_position.lerp(player.position, clock.alpha())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(InputActions.DEBUG_OVERLAY):
		show_overlay = not show_overlay
		overlay.visible = show_overlay
	elif event.is_action_pressed(InputActions.DEBUG_HITBOXES):
		show_hitboxes = not show_hitboxes
	elif event.is_action_pressed(InputActions.DEBUG_RESPAWN):
		_respawn()
	elif event.is_action_pressed(InputActions.DEBUG_DUMMY_ENEMY):
		add_dummy(player_team + 1)
	elif event.is_action_pressed(InputActions.DEBUG_DUMMY_MATE):
		add_dummy(player_team if player_team != Fighter.NO_TEAM else Fighter.NO_TEAM)


## A target toy that stands still: an enemy on another team, or a teammate on the player's.
## `at` puts its feet there; otherwise the match picks a fair spawn point.
func add_dummy(team: int, at: Variant = null, protect: bool = true) -> Fighter:
	var f: Fighter
	if at == null:
		f = combat.spawn(team)
	else:
		f = combat.join(sim.spawn_toy(0, &"plastic_soldier", at), team, protect)
	_add_toy_view(f.toy)
	return f


func _add_toy_view(t: SimToy) -> void:
	var v := ToyView.new(t, sim.rules, combat)
	v.show_hitboxes = show_hitboxes
	toy_views.append(v)
	add_child(v)


func _respawn() -> void:
	var points := sim.map.spawn_points()
	player.position = points[spawn_index % points.size()].global_position + Vector2(0.0, sim.rules.body_bottom - SimToy.SAFE_MARGIN)
	player.prev_position = player.position
	player.velocity = Vector2.ZERO
	player.battery = sim.env.battery_full
	player.jetpack_on = false


func _refuse(errors: PackedStringArray) -> void:
	push_error("ruleset refused: %s" % "; ".join(errors))
	var label := Label.new()
	label.text = "Ruleset refused:\n" + "\n".join(errors)
	label.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	var layer := CanvasLayer.new()
	layer.add_child(label)
	add_child(layer)
