class_name Radar
extends RefCounted
## Edge arrows for toys off screen (US-25.3, T-87), as logic only. A toy gets an arrow while it is
## off screen, within range, and either just fired or moves faster than the speed trigger. The
## arrow brightens while that holds and fades after. Enemies and teammates are marked apart.

## Alpha per second: the classic's +10 and -5 per frame at 60 fps, up to 200 of 255.
const BRIGHTEN := 600.0 / 255.0
const FADE := 300.0 / 255.0
const MAX_ALPHA := 200.0 / 255.0


class Arrow:
	extends RefCounted
	var toy_id: int = 0
	## Direction from the screen centre, y down, length 1.
	var dir: Vector2 = Vector2.ZERO
	var alpha: float = 0.0
	var enemy: bool = true
	var distance: float = 0.0


var rules: ViewRules
## Toy id to its arrow.
var arrows: Dictionary = {}


func _init(view_rules: ViewRules) -> void:
	rules = view_rules


## One frame. `me` is the player's world position, `view` the visible world rect, `my_team` the
## player's team (-1 in free-for-all: everyone is an enemy).
func step(dt: float, me: Vector2, view: Rect2, my_team: int, contacts: Array[HudState.Contact]) -> void:
	var seen := {}
	for c in contacts:
		if not c.alive:
			continue
		seen[c.toy_id] = true
		var d := c.position.distance_to(me)
		var off := not view.grow(rules.radar_margin).has_point(c.position)
		var on := off and d <= rules.radar_range and (c.fired or c.velocity.length() > rules.radar_speed)
		var a: Arrow = arrows.get(c.toy_id)
		if a == null:
			if not on:
				continue
			a = Arrow.new()
			a.toy_id = c.toy_id
			arrows[c.toy_id] = a
		a.enemy = my_team < 0 or c.team != my_team
		a.distance = d
		if c.position != me:
			a.dir = (c.position - me).normalized()
		if on:
			a.alpha = minf(MAX_ALPHA, a.alpha + BRIGHTEN * dt)
		else:
			a.alpha -= FADE * dt
		if not off:
			a.alpha = 0.0
	for id: int in arrows.keys():
		var a: Arrow = arrows[id]
		if not seen.has(id):
			a.alpha -= FADE * dt
		if a.alpha <= 0.0:
			arrows.erase(id)


## Arrows to draw now.
func visible() -> Array[Arrow]:
	var out: Array[Arrow] = []
	for a: Arrow in arrows.values():
		if a.alpha > 0.0:
			out.append(a)
	return out


## Ring radius on a screen `height` points tall.
func ring(height: float) -> float:
	return rules.radar_ring * height
