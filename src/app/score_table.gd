class_name ScoreTable
extends PanelContainer
## The full scoreboard (US-20.1 to US-20.3): one row per toy, best first, with kills, deaths,
## suicides, team kills, damage and best streak. Shown on demand during a match and on the
## results.

const HEADERS: PackedStringArray = ["", "Player", "Kills", "Deaths", "Suicides", "Team kills", "Damage", "Best streak"]

var scores: Scoreboard
var me_id: int = 0
var _grid: GridContainer


func _init(scoreboard: Scoreboard, me: int) -> void:
	scores = scoreboard
	me_id = me
	name = "ScoreTable"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Ui.PANEL, 0.92)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	_grid = GridContainer.new()
	_grid.columns = HEADERS.size()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 1)
	add_child(_grid)
	refresh()


func refresh() -> void:
	for c in _grid.get_children():
		c.free()
	for h in HEADERS:
		_grid.add_child(Ui.label(h, Ui.FONT_SMALL, Ui.TEXT_DIM))
	var rank := 0
	for r: Scoreboard.Row in scores.ranked():
		rank += 1
		var color := Ui.ACCENT if r.id == me_id else Ui.TEXT
		_grid.add_child(Ui.label("%d" % rank, Ui.FONT_SMALL, Ui.TEXT_DIM))
		var who := Ui.label(("%s  " % Ui.TEAM_SHAPES[(r.team - 1) % Ui.TEAM_SHAPES.size()] if r.team > 0 else "") + r.name, Ui.FONT_SMALL, color, HORIZONTAL_ALIGNMENT_LEFT)
		if r.team > 0:
			who.add_theme_color_override("font_color", Ui.team_color(r.team).lerp(Ui.TEXT, 0.25) if r.id != me_id else Ui.ACCENT)
		_grid.add_child(who)
		for v in [r.kills, r.deaths, r.suicides, r.team_kills, roundi(r.damage), r.best_streak]:
			_grid.add_child(Ui.label(str(v), Ui.FONT_SMALL, color))
