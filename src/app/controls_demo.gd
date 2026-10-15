extends Node2D
## Controls, camera and HUD demo: one player toy with touch sticks, keyboard and mouse, a
## teammate and two enemies, on a blockout room. Runs the match on its fixed clock and draws it
## through a `PlayerView`.
##
## Scripted runs for proof (after `--` on the command line):
##   --script=flight   simulated thumbs: walk, take off, fly a loop, aim and fire past the ring
##   --script=hud      a busy HUD moment: feed lines, a hit, radar arrows, low clock
##   --script=popped   the respawn panel
##   --left-handed     mirror the layout
##   --bi              Batteries Included on
##   --frames=DIR      save every drawn frame as DIR/fNNNNN.png (use with --fixed-fps)

const ROOM_W := 3200.0
const FLOOR_Y := 900.0

var rules: Ruleset
var sim: MatchSim
var view: PlayerHud
var camera: GameCamera
var stub := CombatStub.new()
var clock := SimClock.new()
var me: SimToy
var others: Array[SimToy] = []
var script_name: String = ""
var _t: float = 0.0
var _toy_nodes: Dictionary = {}
var _fingers: Dictionary = {}
var _frames_dir: String = ""
var _frame: int = 0
var _prev_t: float = 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--script="):
			script_name = a.get_slice("=", 1)
		elif a.begins_with("--frames="):
			_frames_dir = a.get_slice("=", 1)
	if _frames_dir != "":
		DirAccess.make_dir_recursive_absolute(_frames_dir)
		RenderingServer.frame_post_draw.connect(_save_frame)
	var res := RulesetLoader.load_standard()
	if not res.ok():
		push_error("ruleset: %s" % ", ".join(res.errors))
		return
	rules = res.ruleset
	rules.batteries_included = args.has("--bi")
	sim = MatchSim.new()
	sim.name = "Match"
	sim.setup(rules, _room())
	add_child(sim)
	me = sim.spawn_toy(0)
	for i in 3:
		others.append(sim.spawn_toy(i + 1))
	stub.teams = {me.toy_id: 0, others[0].toy_id: 0, others[1].toy_id: 1, others[2].toy_id: 1}
	stub.names = {me.toy_id: "Sarge", others[0].toy_id: "Bolt", others[1].toy_id: "Plushie", others[2].toy_id: "Tin Tom"}
	stub.scores = _scores(7, 5)
	var gas := HudState.Grenade.new()
	gas.kind = &"gas"
	gas.count = 1
	stub.grenades.append(gas)
	for t in sim.toys:
		_add_toy_view(t)
	InputActions.ensure()
	var settings := ControlSettings.new()
	settings.left_handed = args.has("--left-handed")
	camera = GameCamera.new(rules, settings)
	add_child(camera)
	camera.make_current()
	view = PlayerHud.new()
	view.name = "PlayerHud"
	add_child(view)
	view.setup(sim, me.toy_id, camera, stub)

	view.touch.always_show = true
	for n: Dictionary in _toy_nodes.values():
		n.tag.viewer = _toy_nodes[me.toy_id].outline
	# No tag over your own toy: you know who you are.
	_toy_nodes[me.toy_id].tag.queue_free()
	_toy_nodes[me.toy_id].erase("tag")
	if script_name == "popped":
		stub.popped = true
		stub.respawn_in = 6.4
		stub.popped_by = "Plushie"
		stub.popped_by_team = 1
		stub.popped_with = "the Uzi"
		stub.pop_line("Plushie", 1, "Sarge", 0, "uzi")


func _room() -> GameMap:
	var m := GameMap.new()
	m.name = "DemoRoom"
	m.bounds = Rect2(0, -2400, ROOM_W, FLOOR_Y + 2500)
	var back := Node2D.new()
	back.name = "Backdrop"
	back.set_script(load("res://src/app/demo_backdrop.gd"))
	back.set("room", Rect2(0, -2400, ROOM_W, FLOOR_Y + 2400))
	m.add_child(back)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	terrain.fill = Color("5b4636")
	terrain.edge = Color("2b2233")
	var rects := [
		Rect2(-200, FLOOR_Y, ROOM_W + 400, 300), Rect2(-200, -2400, 200, FLOOR_Y + 2400),
		Rect2(ROOM_W, -2400, 200, FLOOR_Y + 2400),
		Rect2(500, 760, 260, 22), Rect2(900, 640, 220, 22), Rect2(1350, 720, 300, 180),
		Rect2(1800, 560, 240, 22), Rect2(2300, 700, 400, 22), Rect2(1100, 420, 200, 22),
	]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		terrain.add_child(cs)
	m.add_child(terrain)
	var spawns := Node2D.new()
	spawns.name = "Spawns"
	for x: float in [640.0, 760.0, 1250.0, 1550.0]:
		var sp := SpawnPoint.new()
		sp.position = Vector2(x, FLOOR_Y)
		spawns.add_child(sp)
	m.add_child(spawns)
	return m


func _add_toy_view(t: SimToy) -> void:
	var outline := TeamOutline.new()
	outline.name = "Look%d" % t.toy_id
	outline.width = 1.5
	var art := DemoToy.new()
	art.toy = t
	outline.add_child(art)
	add_child(outline)
	outline.set_team(stub.team_of(t.toy_id))
	var tag := NameTag.new()
	tag.player_name = stub.name_of(t.toy_id)
	tag.team = stub.team_of(t.toy_id)
	tag.target = outline
	add_child(tag)
	_toy_nodes[t.toy_id] = {"toy": t, "outline": outline, "tag": tag}


func _scores(a: int, b: int) -> Array[HudState.Score]:
	var out: Array[HudState.Score] = []
	for pair in [[0, a], [1, b]]:
		var s := HudState.Score.new()
		s.team = pair[0]
		s.kills = pair[1]
		s.mine = pair[0] == 0
		out.append(s)
	return out


func _process(dt: float) -> void:
	if sim == null:
		return
	_prev_t = _t
	_t += dt
	_run_script()
	var n := clock.advance(dt)
	for i in n:
		var mine := _intent()
		view.on_intent(mine)
		var intents := {me.toy_id: mine}
		intents.merge(_others_intents(sim.tick * SimClock.TICK))
		sim.step(intents)
	var alpha := clock.alpha()
	for d: Dictionary in _toy_nodes.values():
		var t: SimToy = d.toy
		d.outline.position = t.prev_position.lerp(t.position, alpha)
	camera.follow(me.prev_position.lerp(me.position, alpha), dt)
	view.frame()


## The other toys: the teammate idles, one enemy zips along the far side (radar), one flies up
## and fires now and then.
func _others_intents(time: float) -> Dictionary:
	var out := {}
	var mate := InputIntent.make(Vector2(sin(time * 0.7) * 0.5, 0.0), true, Vector2(1, 0.2))
	out[others[0].toy_id] = mate
	var zip := InputIntent.make(Vector2(1.0 if fmod(time, 6.0) < 3.0 else -1.0, 0.0), true, Vector2(-1, 0))
	out[others[1].toy_id] = zip
	var flyer := InputIntent.make(Vector2(0.3 * sin(time), 0.9 if fmod(time, 4.0) < 2.5 else 0.0), true, Vector2(-1, -0.3))
	out[others[2].toy_id] = flyer
	if fmod(time, 1.5) < SimClock.TICK:
		stub.mark_fired(others[2].toy_id)
	return out


# --- scripted thumbs, for proof ---

func _run_script() -> void:
	match script_name:
		"flight":
			_script_flight()
		"hud":
			_script_hud()


## Screen point in the UI canvas from a share of the layout's control centre.
func _ui(id: TouchLayout.Id) -> Vector2:
	return view.touch.layout.center(id)


func _finger(index: int, pos: Vector2) -> void:
	# Real input events through the engine, as a thumb would send them.
	var window_pos: Vector2 = get_viewport().get_final_transform() * pos
	if not _fingers.has(index):
		var e := InputEventScreenTouch.new()
		e.index = index
		e.position = window_pos
		e.pressed = true
		Input.parse_input_event(e)
	else:
		var d := InputEventScreenDrag.new()
		d.index = index
		d.position = window_pos
		d.relative = window_pos - _fingers[index]
		Input.parse_input_event(d)
	_fingers[index] = window_pos


func _lift(index: int) -> void:
	if not _fingers.has(index):
		return
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _fingers[index]
	e.pressed = false
	Input.parse_input_event(e)
	_fingers.erase(index)


func _script_flight() -> void:
	var r := view.touch.move_stick.radius
	var m := _ui(TouchLayout.Id.MOVE)
	var a := _ui(TouchLayout.Id.AIM)
	var t := _t
	if t < 0.4:
		return
	if t < 1.6:
		_finger(0, m + Vector2(r * 0.8, 0))
	elif t < 3.2:
		# Push up and right: jump, then the jetpack takes over.
		_finger(0, m + Vector2(r * 0.45, -r * 0.95))
	elif t < 6.0:
		# Fly a loop with the thumb circling the stick.
		var ang := (t - 3.2) * 2.2
		_finger(0, m + Vector2(cos(ang), -absf(sin(ang)) - 0.3).normalized() * r)
	elif t < 7.0:
		_lift(0)
	elif t < 8.0:
		_finger(0, m + Vector2(-r * 0.5, -r))
	else:
		_lift(0)
	# Right thumb: aim inside the ring first, then push past it to fire.
	if t > 1.0 and t < 2.4:
		var ang2 := -0.3 - (t - 1.0) * 0.4
		_finger(1, a + Vector2(cos(ang2), sin(ang2)) * r * 0.6)
	elif t >= 2.4 and t < 5.0:
		var ang3 := -0.6 + sin(t * 1.5) * 0.5
		_finger(1, a + Vector2(cos(ang3), sin(ang3)) * r * 1.45)
		if _every(0.25):
			stub.magazine = maxi(stub.magazine - 1, 0)
	elif t >= 5.0 and t < 5.1:
		_lift(1)
	elif t >= 5.4 and t < 5.5:
		# Tap zoom.
		_finger(2, _ui(TouchLayout.Id.ZOOM))
	elif t >= 5.5 and t < 5.6:
		_lift(2)
	elif t >= 6.0 and t < 9.0:
		var ang4 := PI + 0.4
		_finger(1, a + Vector2(cos(ang4), sin(ang4)) * r * (0.5 if t < 7.0 else 1.4))
	elif t >= 9.0:
		_lift(1)


func _script_hud() -> void:
	if _t < 0.05 and stub.feed.is_empty():
		stub.clock = 27.0
		stub.magazine = 3
		stub.reserve = 42
		stub.pop_line("Sarge", 0, "Tin Tom", 1, "pistol")
		stub.pop_line("Plushie", 1, "Bolt", 0, "frag")
		stub.pop_line("Tin Tom", 1, "Tin Tom", 1, "frag")
		stub.weapon_name = "Assault rifle"
		stub.weapon_key = &"assault_rifle"
	if _every(0.6):
		stub.hit_from(others[1].position)
	# Thumbs resting on the sticks for the shot.
	var r := view.touch.move_stick.radius
	if _t > 0.3:
		_finger(0, _ui(TouchLayout.Id.MOVE) + Vector2(r * 0.6, -r * 0.2))
		_finger(1, _ui(TouchLayout.Id.AIM) + Vector2(-r * 1.3, -r * 0.5))


func _save_frame() -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(_frames_dir.path_join("f%05d.png" % _frame))
	_frame += 1


## True on the frame a multiple of `period` seconds passes.
func _every(period: float) -> bool:
	return floori(_t / period) != floori(_prev_t / period)


## The player's intent: touch, or keyboard and mouse aimed from the toy.
func _intent() -> InputIntent:
	var c := view.touch
	if c.is_active() and c.since_touch < TouchInput.TOUCH_GRACE:
		var i := InputIntent.new()
		c.fill(i)
		return i
	var i := InputIntent.new()
	i.move = Input.get_vector(InputActions.MOVE_LEFT, InputActions.MOVE_RIGHT, InputActions.MOVE_DOWN, InputActions.MOVE_UP)
	i.move_held = i.move != Vector2.ZERO
	var to_mouse := get_global_mouse_position() - me.position
	if to_mouse.length() > 1.0:
		i.aim = Vector2(to_mouse.x, -to_mouse.y).normalized()
	i.fire = Input.is_action_pressed(InputActions.FIRE)
	for b: Array in InputActions.BUTTONS:
		i.set_button(b[1], Input.is_action_pressed(b[0]))
	return i
