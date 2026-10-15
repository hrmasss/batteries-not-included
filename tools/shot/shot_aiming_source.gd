class_name ShotAimingSource
extends ScriptedSource
## A scripted run whose aim can track the nearest enemy, so proof shots show a real fight
## without hand-tuned aim vectors. Screenshot runs only.

var track: bool = false


func intent_for(view: GameView, tick: int) -> InputIntent:
	var i := super.intent_for(view, tick)
	if not track or view.combat == null or view.me == null:
		return i
	var best: Fighter = null
	var near := INF
	for f in view.combat.fighters:
		if f == view.me or not f.alive or f.is_teammate(view.me):
			continue
		var d := f.toy.position.distance_squared_to(view.player.position)
		if d < near:
			near = d
			best = f
	if best != null:
		i = i.copy()
		i.aim = aim_from_to(view.player.position, best.toy.position, i.aim)
	return i


## Aim (y up, like the sticks) from one body origin to another.
static func aim_from_to(from: Vector2, to: Vector2, fallback: Vector2) -> Vector2:
	var d := to - from
	if d.length() < 1.0:
		return fallback
	d = d.normalized()
	return Vector2(d.x, -d.y)
