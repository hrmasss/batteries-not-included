class_name TouchControls
extends Control
## Twin sticks and buttons on a touch screen (US-23, US-05.1/.2/.7). Reads screen touches,
## draws the controls and fills an `InputIntent` each tick. Holds no rule: what a stick or a
## button does is decided by the match.
##
## Lay it over the whole screen (full-rect anchors) before `setup`. It hides itself until the first touch, unless `always_show`.

signal zoom_tapped
signal haptic

const Id := TouchLayout.Id

const _ICONS := {
	Id.GRENADE: HudIcons.Kind.GRENADE,
	Id.MELEE: HudIcons.Kind.MELEE,
	Id.RELOAD: HudIcons.Kind.RELOAD,
	Id.SWITCH: HudIcons.Kind.SWITCH,
	Id.PICK_UP: HudIcons.Kind.PICK_UP,
	Id.ZOOM: HudIcons.Kind.ZOOM,
	Id.GRENADE_SWITCH: HudIcons.Kind.GRENADE_SWITCH,
	Id.FIRE: HudIcons.Kind.FIRE,
}
const _ACTS := {
	Id.GRENADE: InputIntent.Act.GRENADE,
	Id.MELEE: InputIntent.Act.MELEE,
	Id.RELOAD: InputIntent.Act.RELOAD,
	Id.SWITCH: InputIntent.Act.SWITCH,
	Id.PICK_UP: InputIntent.Act.PICK_UP,
	Id.ZOOM: InputIntent.Act.ZOOM,
	Id.GRENADE_SWITCH: InputIntent.Act.GRENADE_SWITCH,
}

@export var always_show: bool = false

var view_rules: ViewRules
var settings: ControlSettings
var layout: TouchLayout
var move_stick := TouchStick.new()
var aim_stick := TouchStick.new()
## Text on the zoom button, "1X" to "7X".
var zoom_label: String = "1X"
## The pick-up button shows only when something is in reach.
var can_pick_up: bool = false

## Touch index to the button it pressed.
var _button_touches: Dictionary = {}
## Buttons pressed since the last `fill`, so a tap shorter than a tick still counts.
var _latched: int = 0
var _fire_latched: bool = false
var _active: bool = false
## Seconds since the last touch event of any kind.
var since_touch: float = INF


func setup(rules: ViewRules, control_settings: ControlSettings) -> void:
	view_rules = rules
	settings = control_settings
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	apply_settings()


## Rebuilds the layout and sticks from the settings (call after changing them).
func apply_settings() -> void:
	var screen := size if size != Vector2.ZERO else get_viewport_rect().size
	layout = TouchLayout.build(screen, settings)
	for pair: Array in [[move_stick, Id.MOVE, settings.invert_move], [aim_stick, Id.AIM, settings.invert_aim]]:
		var s: TouchStick = pair[0]
		s.home = layout.center(pair[1])
		if not s.held():
			s.center = s.home
		s.radius = view_rules.stick_radius * settings.stick_size
		s.capture = view_rules.stick_capture * settings.stick_size
		s.knob_return = view_rules.knob_return
		s.floating = settings.floating_sticks
		s.invert = pair[2]
	queue_redraw()


func is_active() -> bool:
	return _active


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and settings != null:
		apply_settings()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _input(event: InputEvent) -> void:
	if settings == null:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var pos := _to_local(e.position)
		if e.pressed:
			touch_down(e.index, pos)
		else:
			touch_up(e.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		touch_move(e.index, _to_local(e.position))
		get_viewport().set_input_as_handled()


## A touch starts at `pos` (this control's space). Buttons first, then the sticks (US-23.2).
func touch_down(index: int, pos: Vector2) -> void:
	_active = true
	since_touch = 0.0
	var b := layout.button_at(pos, settings.fire_button, can_pick_up)
	if b >= 0:
		_button_touches[index] = b
		if b == Id.FIRE:
			_fire_latched = true
		elif _ACTS.has(b):
			_latched |= int(_ACTS[b])
		if b == Id.ZOOM:
			zoom_tapped.emit()
		if settings.haptics:
			haptic.emit()
		queue_redraw()
		return
	var on_move := layout.on_move_side(pos)
	var first: TouchStick = move_stick if on_move else aim_stick
	var second: TouchStick = aim_stick if on_move else move_stick
	if not first.press(index, pos) and not settings.floating_sticks:
		second.press(index, pos)
	if not settings.fire_button and aim_stick.past_ring():
		_fire_latched = true
	queue_redraw()


func touch_move(index: int, pos: Vector2) -> void:
	since_touch = 0.0
	move_stick.drag(index, pos)
	aim_stick.drag(index, pos)
	if not settings.fire_button and index == aim_stick.touch and aim_stick.past_ring():
		_fire_latched = true
	queue_redraw()


func touch_up(index: int) -> void:
	move_stick.release(index)
	aim_stick.release(index)
	_button_touches.erase(index)
	queue_redraw()


func release_all() -> void:
	move_stick.reset()
	aim_stick.reset()
	_button_touches.clear()
	_latched = 0
	_fire_latched = false
	queue_redraw()


## Writes this tick's touch state into `intent`: move, aim, fire and buttons.
func fill(intent: InputIntent) -> void:
	intent.move = move_stick.output()
	intent.move_held = move_stick.held()
	intent.aim = aim_stick.direction()
	var held_buttons := 0
	var fire_held := false
	for b: int in _button_touches.values():
		if b == Id.FIRE:
			fire_held = true
		elif _ACTS.has(b):
			held_buttons |= int(_ACTS[b])
	intent.buttons = held_buttons | _latched
	if settings.fire_button:
		intent.fire = fire_held or _fire_latched
	else:
		intent.fire = aim_stick.past_ring() or _fire_latched
	_latched = 0
	_fire_latched = false


func _process(delta: float) -> void:
	since_touch = 0.0 if move_stick.held() or aim_stick.held() or not _button_touches.is_empty() else since_touch + delta
	var was := move_stick.knob
	move_stick.step(delta)
	aim_stick.step(delta)
	if was != move_stick.knob or aim_stick.knob != Vector2.ZERO:
		queue_redraw()


func _to_local(screen_pos: Vector2) -> Vector2:
	# Touch events arrive in the viewport's canvas space; this control fills the screen.
	return get_global_transform_with_canvas().affine_inverse() * screen_pos


func _draw() -> void:
	if settings == null or layout == null or not (_active or always_show):
		return
	var a := settings.opacity
	_draw_stick(move_stick, a, false)
	_draw_stick(aim_stick, a, not settings.fire_button)
	var pressed := {}
	for b: int in _button_touches.values():
		pressed[b] = true
	for id: int in layout.radii:
		if (id == Id.FIRE and not settings.fire_button) or (id == Id.PICK_UP and not can_pick_up):
			continue
		var c := layout.center(id)
		var r := layout.radius(id)
		var dim := 1.0
		var down: bool = pressed.has(id)
		var fill := HudStyle.PLASTIC_SHADE if down else HudStyle.PLASTIC
		if id == Id.FIRE:
			fill = Color("ff6b5e") if not down else Color("d94a3f")
		HudStyle.disc(self, c + (Vector2(0, 2) if down else Vector2.ZERO), r, Color(fill, 0.92), a * dim)
		HudIcons.draw(self, _ICONS[id], c + (Vector2(0, 2) if down else Vector2.ZERO), r * 0.62, Color(HudStyle.INK, a * dim))
		if id == Id.ZOOM:
			HudStyle.text(self, c + Vector2(-r, r + 13.0), zoom_label, 13, Color(HudStyle.TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _draw_stick(s: TouchStick, a: float, fire_ring: bool) -> void:
	var c := s.center
	var r := s.radius
	var hot := fire_ring and s.past_ring()
	# Base: a recessed plastic dish with the ring edge marked, since the edge is the trigger (T-86).
	draw_circle(c, r + 6.0, Color(HudStyle.INK, 0.35 * a))
	draw_circle(c, r, Color(HudStyle.PLASTIC, 0.16 * a))
	var ring := HudStyle.HIT if hot else HudStyle.PLASTIC
	draw_arc(c, r, 0.0, TAU, 48, Color(ring, (0.95 if hot else 0.6) * a), 3.0 if hot else 2.0, true)
	if fire_ring and not hot:
		# Tick marks on the ring: past here fires.
		for i in 8:
			var t := TAU * i / 8.0
			var d := Vector2(cos(t), sin(t))
			draw_line(c + d * (r - 4.0), c + d * (r + 4.0), Color(HudStyle.PLASTIC, 0.5 * a), 2.0, true)
	var knob_r := r * 0.55
	HudStyle.disc(self, c + s.knob, knob_r, Color(HudStyle.HIT if hot else HudStyle.PLASTIC, 0.95), a)
	if fire_ring:
		HudIcons.draw(self, HudIcons.Kind.FIRE, c + s.knob, knob_r * 0.6, Color(HudStyle.INK, 0.8 * a))
