class_name DebugOverlay
extends CanvasLayer
## Live readouts for tuning (start of US-37.2): speed, battery, airtime, time since thrust,
## state, frame time. F1 shows or hides it; F2 draws hitboxes (US-37.5).

var _label: Label
var _panel: PanelContainer
var _frame_ms: float = 0.0


func _ready() -> void:
	layer = 50
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.62)
	style.set_content_margin_all(4.0)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(6, 6)
	_label = Label.new()
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	_label.add_theme_font_override("font", mono)
	_label.add_theme_font_size_override("font_size", 9)
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	_panel.add_child(_label)
	add_child(_panel)


func show_toy(toy: SimToy, tick: int, frame_seconds: float, hitboxes: bool) -> void:
	if not visible:
		return
	# Smooth the frame time a little so it can be read.
	_frame_ms = lerpf(_frame_ms, frame_seconds * 1000.0, 0.1) if _frame_ms > 0.0 else frame_seconds * 1000.0
	var lines: PackedStringArray = [
		"state     %s%s" % [toy.mode_name(), "  (jetpack on)" if toy.jetpack_on else ""],
		"speed     %6.1f u/s   (%5.1f, %5.1f)" % [toy.speed(), toy.velocity.x, -toy.velocity.y],
		"battery   %6.1f / %.0f   thrust %.2f" % [toy.battery, toy.battery_max, toy.thrust],
		"airtime   %6.2f s" % toy.airtime,
		"no thrust %6.2f s" % minf(toy.since_thrust, 999.99),
		"flown     %6.2f s" % toy.flight_time,
		"frame     %6.2f ms   %3d fps   tick %d" % [_frame_ms, Engine.get_frames_per_second(), tick],
		"F1 overlay  F2 hitboxes %s  F5 respawn" % ("on" if hitboxes else "off"),
	]
	_label.text = "\n".join(lines)
