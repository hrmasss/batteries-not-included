class_name CombatSim
extends RefCounted
## Fighting on the match server: weapons, bullets, melee, grenades, blasts, health, pops,
## kill credit, respawns, spawn protection and pickups (01_world "Weapons and damage" to
## "Spawning"; 04_tuning T-24, T-30 to T-77). Rule A1: only this class writes fighting state.
##
## `MatchSim` steps it once per tick, after movement, with the same sanitized intents. Every
## number comes from the ruleset; the only literals here are 0, 1 and the solver constants
## below. Random rolls (spread, pickup draws, spawn picks) come from one seeded generator the
## match owns (T-44: rolled by the match server).
##
## World space is y down, like `SimToy`. Intent vectors are y up.

## How close a resting grenade or item sits to the surface it hit. Solver detail, not tuning.
const SURFACE_GAP := 0.5
## Below this speed a bouncing grenade or rocket comes to rest. Solver detail, not tuning.
const REST_SPEED := 1.0
## Slack when comparing match times. Solver detail, not tuning.
const TIME_EPSILON := 0.000001

enum Hurt { BULLET, MELEE, BLAST, DIRECT, WORLD }

## Item kinds a pickup point may list besides weapon ids.
const HEALTH_PACK := &"health_pack"
const BATTERY_PACK := &"battery_pack"
## Weapon id credited for out-of-bounds damage.
const OUT_OF_BOUNDS := &"out_of_bounds"
const BARE_HANDS := &"bare_hands"


class Bullet:
	extends RefCounted
	var owner: int = 0
	var weapon: StringName = &""
	var pos: Vector2
	var vel: Vector2
	var damage: float = 0.0
	var range: float = 0.0
	var travelled: float = 0.0


class Rocket:
	extends RefCounted
	var owner: int = 0
	var weapon: StringName = &""
	var pos: Vector2
	var vel: Vector2
	var age: float = 0.0


class Grenade:
	extends RefCounted
	var owner: int = 0
	var type: StringName = &"frag"
	var pos: Vector2
	var vel: Vector2
	var age: float = 0.0


class FloorItem:
	extends RefCounted
	var uid: int = 0
	## A weapon id, a grenade type, or HEALTH_PACK / BATTERY_PACK.
	var item: StringName = &""
	## Set for weapons: the gun with its own ammo.
	var weapon: WeaponItem = null
	var pos: Vector2
	var vel: Vector2
	var resting: bool = false
	var age: float = 0.0
	var lifetime: float = 0.0
	## Index of the pickup point it came from; -1 for a dropped item.
	var point: int = -1


class PointState:
	extends RefCounted
	var point: PickupPoint
	var next_at: float = 0.0
	var item_uid: int = -1


## Every fighting event of the match, as it happens: shots, hits, blocks, blasts, pops,
## spawns, pickups. The view draws from it; the network will send it.
signal event(e: Dictionary)

var sim: MatchSim
var rules: Ruleset
var rng := RandomNumberGenerator.new()
## Seconds of match time.
var time: float = 0.0
## Team spawn groups in use (US-22.6). Set by the mode.
var team_spawns: bool = false

var fighters: Array[Fighter] = []
var bullets: Array[Bullet] = []
var rockets: Array[Rocket] = []
var grenades: Array[Grenade] = []
var items: Array[FloorItem] = []
var points: Array[PointState] = []
## This tick's events, for tests and for a view that polls.
var events: Array[Dictionary] = []

var _next_uid: int = 1
var _spawn_used: Dictionary = {}


func _init(match_sim: MatchSim, seed_value: int = 0) -> void:
	sim = match_sim
	rules = match_sim.rules
	rng.seed = seed_value
	for p: PickupPoint in sim.map.pickup_points():
		var s := PointState.new()
		s.point = p
		points.append(s)


# --- toys joining, spawning and respawning ---------------------------------------------

## Makes `toy` a fighter on `team`, with full health and the spawn kit (US-07.2, US-14.1).
## `protect` gives spawn protection (T-68), as a real spawn does.
func join(toy: SimToy, team: int = Fighter.NO_TEAM, protect: bool = true) -> Fighter:
	var f := Fighter.new()
	f.toy = toy
	f.team = team
	fighters.append(f)
	_equip(f, protect)
	return f


## Spawns a new toy at a fair spawn point (US-22.1) and makes it a fighter.
func spawn(team: int = Fighter.NO_TEAM, toy_type: StringName = &"plastic_soldier") -> Fighter:
	var f := Fighter.new()
	f.team = team
	var p := choose_spawn(f)
	var feet: Vector2 = p.global_position if p != null else Vector2.ZERO
	f.toy = sim.spawn_toy(0, toy_type, feet)
	fighters.append(f)
	_equip(f, true)
	_emit({"type": &"spawn", "toy": f.id(), "pos": f.toy.position})
	return f


## US-10.4: the player's zoom mode, from their settings. Takes effect at the next weapon change.
func set_zoom_mode(f: Fighter, mode: Fighter.ZoomMode) -> void:
	f.zoom_mode = mode


func fighter(toy_id: int) -> Fighter:
	for f in fighters:
		if f.id() == toy_id:
			return f
	return null


## A toy leaves the match: its held weapon drops where it stood and its toy goes away.
func leave(toy_id: int) -> void:
	var f := fighter(toy_id)
	if f == null:
		return
	if f.alive:
		var w := f.main_weapon()
		if w != null:
			w.cancel_reload()
			_drop(w, f.toy.position, f.toy.velocity)
	fighters.erase(f)
	f.alive = false
	f.toy.active = false
	sim.remove_toy(f.toy)
	_emit({"type": &"leave", "toy": toy_id})


func _equip(f: Fighter, protect: bool) -> void:
	var t := f.toy
	f.alive = true
	t.active = true
	t.health = rules.max_health
	f.weapons.clear()
	for id: StringName in rules.weapons.kit_weapons:
		f.weapons.append(WeaponItem.fresh(rules.weapons.get_def(id)))
	f.held = 0
	f.grenades.clear()
	for g: StringName in rules.weapons.kit_grenades:
		f.grenades[g] = int(f.grenades.get(g, 0)) + 1
	f.grenade_type = rules.weapons.kit_grenades[0] if not rules.weapons.kit_grenades.is_empty() else &""
	f.protect_left = rules.spawn_protection if protect else 0.0
	f.lunge_meter = rules.lunge_meter_max
	f.swing_left = 0.0
	f.pack_pending = 0.0
	f.battery_pack_left = 0.0
	f.out_of_bounds_time = 0.0
	f.last_damager = 0
	f.zoom_memory.clear()
	f.zoom_level = 1
	_apply_zoom_memory(f)
	_update_weight(f)


func _respawn(f: Fighter) -> void:
	var p := choose_spawn(f)
	var feet: Vector2 = p.global_position if p != null else f.toy.position
	var t := f.toy
	sim.place_toy(t, feet)
	t.velocity = Vector2.ZERO
	t.jetpack_on = false
	t.thrust = 0.0
	t.airtime = 0.0
	t.set_crouched(false)
	t.battery = t.battery_max
	_equip(f, true)
	_emit({"type": &"spawn", "toy": f.id(), "pos": t.position})


## T-71: score every allowed point by distance to living enemies and live explosives, pick
## at random from the best share, skip points used in the last few seconds.
func choose_spawn(f: Fighter) -> SpawnPoint:
	var all := sim.map.spawn_points()
	var allowed: Array[SpawnPoint] = []
	if team_spawns and f.team != Fighter.NO_TEAM:
		for p in all:
			if p.team == f.team:
				allowed.append(p)
	if allowed.is_empty():
		for p in all:
			if not team_spawns or p.team < 0 or p.team == f.team or f.team == Fighter.NO_TEAM:
				allowed.append(p)
	if allowed.is_empty():
		allowed = all
	if allowed.is_empty():
		return null
	var explosives: Array[Vector2] = []
	for g in grenades:
		explosives.append(g.pos)
	for r in rockets:
		explosives.append(r.pos)
	var scored: Array = []
	for i in allowed.size():
		var at := allowed[i].global_position
		var score := 0.0
		for other in fighters:
			if other != f and other.alive and not f.is_teammate(other):
				score += rules.spawn_enemy_weight * at.distance_to(other.toy.position)
		for e in explosives:
			score += rules.spawn_explosive_weight * at.distance_to(e)
		scored.append([score, i])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] or (a[0] == b[0] and a[1] < b[1]))
	var pool := maxi(1, ceili(scored.size() * rules.spawn_pick_share))
	var start := rng.randi_range(0, pool - 1)
	var pick: SpawnPoint = allowed[scored[start][1]]
	for k in scored.size():
		var p: SpawnPoint = allowed[scored[(start + k) % scored.size()][1]]
		if time - float(_spawn_used.get(p.get_instance_id(), -INF)) >= rules.spawn_reuse_block:
			pick = p
			break
	_spawn_used[pick.get_instance_id()] = time
	return pick


# --- the tick ---------------------------------------------------------------------------

## One tick. `intents` maps toy id to its sanitized `InputIntent`.
func step(intents: Dictionary, dt: float) -> void:
	events.clear()
	# From the tick count, not a running sum, so schedules never drift.
	time = (sim.tick + 1) * dt
	for f in fighters:
		if f.alive:
			_act(f, intents.get(f.id(), InputIntent.idle()), dt)
	_step_bullets(dt)
	_step_rockets(dt)
	_step_grenades(dt)
	for f in fighters:
		if f.alive:
			_step_body(f, dt)
	_step_items(dt)
	_step_points()
	for f in fighters:
		if not f.alive:
			f.respawn_left -= dt
			if f.respawn_left <= 0.0:
				_respawn(f)
	for f in fighters:
		var i: InputIntent = intents.get(f.id(), null)
		f.prev_buttons = i.buttons if i != null else 0


func _pressed(f: Fighter, intent: InputIntent, button: InputIntent.Act) -> bool:
	return intent.is_down(button) and f.prev_buttons & int(button) == 0


## What a living toy does this tick, from its intent.
func _act(f: Fighter, intent: InputIntent, dt: float) -> void:
	# US-05.1: aim along the thumb's angle, at any distance from the centre.
	if intent.aim != Vector2.ZERO:
		f.aim = Vector2(intent.aim.x, -intent.aim.y).normalized()
	if _pressed(f, intent, InputIntent.Act.SWITCH):
		_switch(f)
	if _pressed(f, intent, InputIntent.Act.RELOAD):
		for w in [f.main_weapon(), f.off_weapon()]:
			if w != null:
				(w as WeaponItem).start_reload()
	if _pressed(f, intent, InputIntent.Act.ZOOM):
		_zoom_step(f)
	if _pressed(f, intent, InputIntent.Act.GRENADE_SWITCH):
		_grenade_switch(f)
	if _pressed(f, intent, InputIntent.Act.PICK_UP):
		_pick_up(f)
	if _pressed(f, intent, InputIntent.Act.GRENADE):
		_throw(f)
	if _pressed(f, intent, InputIntent.Act.MELEE) and f.swing_left <= 0.0:
		_start_swing(f)

	# Fire: each hand on its own interval and magazine (US-05.3, US-08.2).
	var infinite := rules.batteries_included
	var main := f.main_weapon()
	var off := f.off_weapon()
	for w in f.weapons:
		var trigger := intent.fire and (w == main or w == off)
		var shots := w.step(dt, trigger, infinite)
		for s in shots:
			_shoot(f, w)

	if f.swing_left > 0.0:
		f.swing_left -= dt
		if not f.swing_landed:
			_land_swing(f)
	f.lunge_meter = minf(rules.lunge_meter_max, f.lunge_meter + rules.lunge_refill * dt)
	_update_weight(f)


func _update_weight(f: Fighter) -> void:
	var weights := PackedFloat32Array()
	var main := f.main_weapon()
	if main != null:
		weights.append(main.def.weight)
		var off := f.off_weapon()
		if off != null:
			weights.append(off.def.weight)
	f.toy.weapon_weights = weights


## US-22.5: protection ends the moment the toy attacks.
func _attacked(f: Fighter) -> void:
	if f.protect_left > 0.0:
		f.protect_left = 0.0
		_emit({"type": &"protection_end", "toy": f.id()})


# --- weapons --------------------------------------------------------------------------

## US-07.4: swap the held weapon for the other one.
func _switch(f: Fighter) -> void:
	if f.weapons.size() < Fighter.SLOTS:
		return
	var put_away := f.main_weapon()
	f.held = 1 - f.held
	if not f.is_dual():
		put_away.cancel_reload()
	_apply_zoom_memory(f)
	_emit({"type": &"switch", "toy": f.id(), "weapon": f.main_weapon().id()})


## US-10.1, US-10.2: step to the held weapon's next allowed zoom level.
func _zoom_step(f: Fighter) -> void:
	var w := f.main_weapon()
	if w == null:
		return
	var levels := w.def.zoom
	var i := levels.find(f.zoom_level)
	f.zoom_level = levels[(i + 1) % levels.size()] if i >= 0 else levels[0]
	f.zoom_memory[w.id()] = f.zoom_level


## US-10.3, US-10.4: the level for the weapon now held, by the player's zoom mode. Last used:
## back to the level last used with this weapon, or the nearest allowed one.
func _apply_zoom_memory(f: Fighter) -> void:
	var w := f.main_weapon()
	if w == null:
		f.zoom_level = 1
		return
	var levels := w.def.zoom
	match f.zoom_mode:
		Fighter.ZoomMode.WIDEST:
			f.zoom_level = levels[levels.size() - 1]
			return
		Fighter.ZoomMode.KEEP:
			var below: int = levels[0]
			for level in levels:
				if level <= f.zoom_level:
					below = level
			f.zoom_level = below
			return
	if f.zoom_memory.has(w.id()):
		f.zoom_level = f.zoom_memory[w.id()]
		return
	var best: int = levels[0]
	for level in levels:
		if absi(level - f.zoom_level) < absi(best - f.zoom_level):
			best = level
	f.zoom_level = best


## One shot: every pellet within the spread of the aim, rolled here (T-44, US-05.4).
func _shoot(f: Fighter, w: WeaponItem) -> void:
	_attacked(f)
	var d := w.def
	var origin := f.toy.position
	for p in d.pellets:
		var dir := f.aim.rotated(deg_to_rad(rng.randf_range(-d.spread, d.spread)))
		if d.kind == WeaponDef.ROCKET:
			var r := Rocket.new()
			r.owner = f.id()
			r.weapon = d.id
			r.pos = origin
			r.vel = (dir * d.bullet_speed + f.toy.velocity * rules.inherit_velocity).limit_length(rules.rocket_speed_cap)
			rockets.append(r)
		else:
			var b := Bullet.new()
			b.owner = f.id()
			b.weapon = d.id
			b.pos = origin
			b.vel = dir * d.bullet_speed + f.toy.velocity * rules.inherit_velocity
			b.damage = d.damage
			b.range = d.range
			bullets.append(b)
	_emit({"type": &"shot", "toy": f.id(), "weapon": d.id, "dir": f.aim, "off_hand": w == f.off_weapon()})


## T-41: full damage to the falloff start, then falling to half at max range.
func falloff(distance: float, weapon_range: float) -> float:
	var start := weapon_range * rules.falloff_start_share
	if distance <= start:
		return 1.0
	return maxf(0.0, 1.0 - (distance - start) / weapon_range)


## US-06.1: bullets move at their speed, stop at the first wall or toy, never pass their range.
func _step_bullets(dt: float) -> void:
	var keep: Array[Bullet] = []
	for b in bullets:
		var speed := b.vel.length()
		var dir := b.vel / speed if speed > 0.0 else Vector2.RIGHT
		var length := minf(speed * dt, b.range - b.travelled)
		var to := b.pos + dir * length
		var wall := _terrain_hit(b.pos, to)
		var wall_t: float = wall.t if not wall.is_empty() else INF
		var hit := _toy_hit(b.pos, to, fighter(b.owner))
		if not hit.is_empty() and hit.t <= wall_t:
			var victim: Fighter = hit.fighter
			var travelled: float = b.travelled + length * float(hit.t)
			var dmg := b.damage * falloff(travelled, b.range)
			var head: bool = hit.head and not victim.toy.crouched
			if head:
				dmg *= rules.headshot_factor
			hurt(victim, dmg, b.owner, b.weapon, Hurt.BULLET, _knockback(dir, dmg), head)
			continue
		if not wall.is_empty():
			_emit({"type": &"impact", "pos": wall.pos, "weapon": b.weapon})
			continue
		b.pos = to
		b.travelled += length
		if b.travelled < b.range:
			keep.append(b)
	bullets = keep


## T-33: knockback along the hit, in proportion to the damage, capped per axis.
func _knockback(dir: Vector2, dmg: float) -> Vector2:
	var v := dir * dmg * rules.knockback_per_hp
	return Vector2(clampf(v.x, -rules.knockback_cap, rules.knockback_cap), clampf(v.y, -rules.knockback_cap, rules.knockback_cap))


# --- melee ------------------------------------------------------------------------------

## US-09.1, US-09.3: swing for the swing time and lunge along the aim while the meter allows.
func _start_swing(f: Fighter) -> void:
	_attacked(f)
	f.swing_left = rules.melee_swing
	f.swing_dir = f.aim
	f.swing_landed = false
	var t := f.toy
	var weight := t.weight_factor(rules)
	var lunged := false
	if f.lunge_meter >= rules.lunge_cost:
		var along := t.velocity.dot(f.swing_dir)
		if t.velocity.length() < rules.lunge_speed_cap * weight or along < 0.0:
			if along < f.lunge_meter:
				t.velocity += f.swing_dir * (f.lunge_meter - along)
			f.lunge_meter -= rules.lunge_cost
			lunged = true
	_emit({"type": &"swing", "toy": f.id(), "dir": f.swing_dir, "lunge": lunged})


## US-09.2, US-09.4: the first enemy the swing reaches takes the melee damage of the held
## weapon, or bare-hand damage, once per swing; never a headshot.
func _land_swing(f: Fighter) -> void:
	var w := f.main_weapon()
	var reach := w.def.melee_reach if w != null else rules.bare_hand_reach
	var dmg := w.def.melee_damage if w != null else rules.bare_hand_damage
	var weapon_id: StringName = w.id() if w != null else BARE_HANDS
	var best: Fighter = null
	var best_d := INF
	for other in fighters:
		if other == f or not other.alive or f.is_teammate(other):
			continue
		var box := other.toy.hit_bounds()
		var nearest := Vector2(clampf(f.toy.position.x, box.position.x, box.end.x), clampf(f.toy.position.y, box.position.y, box.end.y))
		var d := f.toy.position.distance_to(nearest)
		if d > reach or (other.toy.position - f.toy.position).dot(f.swing_dir) < 0.0:
			continue
		if d < best_d:
			best = other
			best_d = d
	if best != null:
		f.swing_landed = true
		hurt(best, dmg, f.id(), weapon_id, Hurt.MELEE, _knockback(f.swing_dir, dmg))


# --- grenades, rockets and blasts ---------------------------------------------------------

## US-12.1: throw the current type along the aim at the throw speed plus the toy's velocity.
func _throw(f: Fighter) -> void:
	if f.grenade_count() <= 0:
		return
	if int(f.grenades.get(f.grenade_type, 0)) <= 0:
		_grenade_switch(f)
	var type := f.grenade_type
	f.grenades[type] = int(f.grenades[type]) - 1
	_attacked(f)
	var hand := f.toy.position
	var at := hand + f.aim * rules.throw_offset
	var wall := _terrain_hit(hand, at)
	if not wall.is_empty():
		at = (wall.pos as Vector2) - f.aim * SURFACE_GAP
	var g := Grenade.new()
	g.owner = f.id()
	g.type = type
	g.pos = at
	g.vel = f.toy.velocity + f.aim * rules.throw_speed
	grenades.append(g)
	_emit({"type": &"throw", "toy": f.id(), "grenade": type, "pos": at})


## US-12.4: move to the next grenade type the toy holds.
func _grenade_switch(f: Fighter) -> void:
	var types := WeaponTable.GRENADES
	var i := types.find(f.grenade_type)
	for k in range(1, types.size() + 1):
		var next: StringName = types[(i + k) % types.size()]
		if int(f.grenades.get(next, 0)) > 0:
			f.grenade_type = next
			return


## US-12.2: a frag bounces until its fuse runs out, then blasts.
func _step_grenades(dt: float) -> void:
	var keep: Array[Grenade] = []
	var gravity := Vector2(0.0, rules.frag_gravity * sim.map.item_gravity)
	for g in grenades:
		g.age += dt
		if g.age >= rules.frag_fuse:
			blast(g.pos, rules.frag_power, g.owner, g.type)
			continue
		g.vel = g.vel * pow(rules.frag_speed_kept, dt) + gravity * dt
		g.pos = _bounce_move(g.pos, g, dt, rules.frag_bounce, rules.frag_friction)
		keep.append(g)
	grenades = keep


## Moves a grenade or rocket one tick, bouncing off terrain. Returns the new position.
func _bounce_move(pos: Vector2, body: Object, dt: float, bounce: float, friction: float) -> Vector2:
	var vel: Vector2 = body.get("vel")
	var to := pos + vel * dt
	var wall := _terrain_hit(pos, to)
	if wall.is_empty():
		return to
	var n: Vector2 = wall.normal
	var vn := vel.dot(n)
	if vn < 0.0:
		var tangent := vel - n * vn
		var push := -(1.0 + bounce) * vn
		vel += n * push
		var vt := tangent.length()
		if vt > 0.0:
			vel -= tangent / vt * minf(vt, friction * push)
	if vel.length() < REST_SPEED:
		vel = Vector2.ZERO
	body.set("vel", vel)
	return (wall.pos as Vector2) + n * SURFACE_GAP


## T-67: a rocket flies straight, hits toys directly, blasts on walls once armed, and
## self-destructs at the end of its life. Teammates let it through, as they do bullets.
func _step_rockets(dt: float) -> void:
	var keep: Array[Rocket] = []
	for r in rockets:
		r.age += dt
		if r.age >= rules.rocket_life:
			blast(r.pos, rules.rocket_power, r.owner, r.weapon)
			continue
		var to := r.pos + r.vel * dt
		var wall := _terrain_hit(r.pos, to)
		var wall_t: float = wall.t if not wall.is_empty() else INF
		var hit := _toy_hit(r.pos, to, fighter(r.owner))
		if not hit.is_empty() and hit.t <= wall_t:
			var at := r.pos.lerp(to, hit.t)
			var victim: Fighter = hit.fighter
			var dir := r.vel.normalized()
			hurt(victim, rules.rocket_direct_damage, r.owner, r.weapon, Hurt.DIRECT, _knockback(dir, rules.rocket_direct_damage))
			blast(at, rules.rocket_power, r.owner, r.weapon)
			continue
		if not wall.is_empty():
			if r.age >= rules.rocket_arm_time:
				blast((wall.pos as Vector2) + (wall.normal as Vector2) * SURFACE_GAP, rules.rocket_power, r.owner, r.weapon)
				continue
			r.pos = _bounce_move(r.pos, r, dt, rules.rocket_bounce, 0.0)
		else:
			r.pos = to
		keep.append(r)
	rockets = keep


## US-13.1 to US-13.4: a blast hurts every toy inside its radius by distance, the thrower and
## teammates included; behind a wall only the minimum; knocks toys back. T-63.
func blast(at: Vector2, power: float, owner: int, weapon: StringName) -> void:
	var radius := rules.blast_radius * power
	_emit({"type": &"blast", "pos": at, "radius": radius, "power": power, "owner": owner, "weapon": weapon, "shake_reach": rules.blast_shake_reach * power})
	for f: Fighter in fighters.duplicate():
		if not f.alive:
			continue
		var d := at.distance_to(f.toy.position)
		if d > radius:
			continue
		var dmg := maxf((rules.blast_damage * power - rules.blast_falloff * d) * power, rules.blast_min_damage)
		var push := Vector2.ZERO
		if not _terrain_hit(at, f.toy.position).is_empty():
			dmg = rules.blast_min_damage
		else:
			var dir := (f.toy.position - at).normalized() if d > 0.0 else Vector2.UP
			push = dir * minf(dmg, rules.blast_knockback_cap) * rules.blast_knockback_per_hp
		hurt(f, dmg, owner, weapon, Hurt.BLAST, push)


# --- damage, health and pops --------------------------------------------------------------

## The one way a toy loses health. Spawn protection blocks everything (US-13.3, US-22.4).
## `attacker` 0 means no attacker (out of bounds); the kill then goes to the last damager.
func hurt(f: Fighter, amount: float, attacker: int, weapon: StringName, kind: Hurt, push: Vector2 = Vector2.ZERO, head: bool = false) -> void:
	if not f.alive or amount <= 0.0:
		return
	if f.is_protected():
		_emit({"type": &"blocked", "toy": f.id(), "attacker": attacker, "weapon": weapon})
		return
	f.toy.health = maxf(0.0, f.toy.health - amount)
	if attacker != 0:
		f.last_damager = attacker
	f.toy.velocity += push
	_emit({"type": &"hit", "toy": f.id(), "attacker": attacker, "weapon": weapon, "kind": kind, "amount": amount, "head": head, "pos": f.toy.position})
	if f.toy.health <= 0.0:
		_pop(f, attacker if attacker != 0 else f.last_damager, weapon)


## US-15.2, US-13.5: credit the pop; drop the held weapon (US-07.6); start the respawn wait.
func _pop(f: Fighter, killer_id: int, weapon: StringName) -> void:
	f.alive = false
	f.toy.active = false
	f.deaths += 1
	f.respawn_left = rules.respawn_wait
	f.popped_by = killer_id
	f.popped_with = weapon
	var killer := fighter(killer_id)
	var credit := &"kill"
	if killer == null or killer == f:
		f.suicides += 1
		credit = &"suicide"
	elif killer.is_teammate(f):
		killer.suicides += 1
		killer.team_kills += 1
		credit = &"team_kill"
	else:
		killer.kills += 1
	var w := f.main_weapon()
	if w != null:
		w.cancel_reload()
		_drop(w, f.toy.position, f.toy.velocity)
		f.weapons.erase(w)
	_emit({"type": &"pop", "toy": f.id(), "killer": killer_id, "weapon": weapon, "credit": credit, "pos": f.toy.position})


## Health regen and packs (US-14.2, US-14.3), battery pack (US-14.4), out of bounds (US-14.5),
## protection running out.
func _step_body(f: Fighter, dt: float) -> void:
	var t := f.toy
	if f.protect_left > 0.0:
		f.protect_left -= dt
		if f.protect_left <= 0.0:
			f.protect_left = 0.0
			_emit({"type": &"protection_end", "toy": f.id()})
	if f.pack_pending > 0.0:
		var flow := minf(f.pack_pending, rules.pack_flow_rate * dt)
		t.health = minf(rules.max_health, t.health + flow)
		f.pack_pending = 0.0 if t.health >= rules.max_health else f.pack_pending - flow
	if t.health < rules.max_health:
		t.health = minf(rules.max_health, t.health + rules.regen_rate * dt)
	if f.battery_pack_left > 0.0:
		f.battery_pack_left = maxf(0.0, f.battery_pack_left - dt)
		t.battery = t.battery_max
	if sim.map.bounds.has_point(t.position):
		f.out_of_bounds_time = 0.0
	else:
		f.out_of_bounds_time += dt
		while f.alive and f.out_of_bounds_time >= rules.out_of_bounds_interval:
			f.out_of_bounds_time -= rules.out_of_bounds_interval
			hurt(f, rules.out_of_bounds_damage, 0, OUT_OF_BOUNDS, Hurt.WORLD)


# --- pickups ------------------------------------------------------------------------------

func _drop(w: WeaponItem, at: Vector2, vel: Vector2) -> FloorItem:
	var it := _add_item(w.id(), at, -1)
	it.weapon = w
	it.vel = vel
	it.lifetime = rules.empty_gun_lifetime if w.is_empty() else rules.dropped_gun_lifetime
	_emit({"type": &"drop", "item": it.uid, "weapon": w.id(), "pos": at})
	return it


func _add_item(item: StringName, at: Vector2, point: int) -> FloorItem:
	var it := FloorItem.new()
	it.uid = _next_uid
	_next_uid += 1
	it.item = item
	it.pos = at
	it.point = point
	items.append(it)
	return it


## Puts an item on the floor, as a map point or a test would. Weapons come fresh.
func place_item(item: StringName, at: Vector2, lifetime: float = INF) -> FloorItem:
	var it := _add_item(item, at, -1)
	if rules.weapons.has(item):
		it.weapon = WeaponItem.fresh(rules.weapons.get_def(item))
	it.lifetime = lifetime
	return it


func item(uid: int) -> FloorItem:
	for it in items:
		if it.uid == uid:
			return it
	return null


## T-77: above the crowding threshold, lifetimes shrink toward the shortest share.
func crowd_share() -> float:
	var over := clampf((items.size() - rules.crowd_start) / (rules.crowd_full - rules.crowd_start), 0.0, 1.0)
	return 1.0 - over * (1.0 - rules.crowd_min_share)


## The lifetime an item has now, after crowding.
func item_lifetime(it: FloorItem) -> float:
	return it.lifetime * crowd_share()


## 1 while the item shows fully, falling to 0 over the fade before it goes (US-16.4).
func item_alpha(it: FloorItem) -> float:
	if rules.floor_fade <= 0.0:
		return 1.0
	return clampf((item_lifetime(it) - it.age) / rules.floor_fade, 0.0, 1.0)


func _reach_point(f: Fighter) -> Vector2:
	return f.toy.position + Vector2(0.0, -rules.pickup_reach_up)


func _step_items(dt: float) -> void:
	var gravity := Vector2(0.0, rules.walk_gravity * sim.map.item_gravity)
	var keep: Array[FloorItem] = []
	for it in items:
		it.age += dt
		if it.age >= item_lifetime(it):
			_emit({"type": &"expire", "item": it.uid})
			continue
		if not it.resting:
			it.vel += gravity * dt
			var to := it.pos + it.vel * dt
			var wall := _terrain_hit(it.pos, to)
			if wall.is_empty():
				it.pos = to
			else:
				it.pos = (wall.pos as Vector2) + (wall.normal as Vector2) * SURFACE_GAP
				it.vel = Vector2.ZERO
				it.resting = true
		keep.append(it)
	items = keep
	for f in fighters:
		if not f.alive:
			continue
		f.offer = -1
		var best := INF
		for it: FloorItem in items.duplicate():
			var d := _reach_point(f).distance_to(it.pos)
			if d > rules.pickup_reach:
				continue
			if it.weapon != null:
				if d < best:
					best = d
					f.offer = it.uid
			elif _auto_take(f, it):
				items.erase(it)


## Packs and grenades are taken by touch when they help: a grenade under the cap (US-12.3),
## a health pack below full (US-14.3), a battery pack always (US-14.4).
func _auto_take(f: Fighter, it: FloorItem) -> bool:
	var t := f.toy
	if WeaponTable.GRENADES.has(it.item):
		if f.grenade_count() >= rules.grenade_cap:
			return false
		f.grenades[it.item] = int(f.grenades.get(it.item, 0)) + 1
		if int(f.grenades.get(f.grenade_type, 0)) <= 0:
			f.grenade_type = it.item
	elif it.item == HEALTH_PACK:
		if t.health >= rules.max_health:
			return false
		t.health = minf(rules.max_health, t.health + rules.pack_instant)
		f.pack_pending = rules.pack_flow
	elif it.item == BATTERY_PACK:
		f.battery_pack_left = rules.battery_pack_time
		t.battery = t.battery_max
	else:
		return false
	_emit({"type": &"pickup", "toy": f.id(), "item": it.item, "uid": it.uid})
	return true


## US-07.3: take the offered weapon; with both hands full, it replaces the held one, which drops.
func _pick_up(f: Fighter) -> void:
	var it := item(f.offer)
	if it == null or it.weapon == null:
		return
	if _reach_point(f).distance_to(it.pos) > rules.pickup_reach:
		return
	items.erase(it)
	f.offer = -1
	if f.weapons.size() < Fighter.SLOTS:
		f.weapons.append(it.weapon)
		f.held = f.weapons.size() - 1
	else:
		var old := f.main_weapon()
		old.cancel_reload()
		_drop(old, f.toy.position, Vector2.ZERO)
		f.weapons[f.held] = it.weapon
	_apply_zoom_memory(f)
	_update_weight(f)
	_emit({"type": &"pickup", "toy": f.id(), "item": it.item, "uid": it.uid})


## US-16.1 to US-16.3: each point spawns one item from its list on its interval.
func _step_points() -> void:
	if rules.pickup_interval <= 0.0:
		return
	for i in points.size():
		var s := points[i]
		if time + TIME_EPSILON < s.next_at:
			continue
		var interval := s.point.interval if s.point.interval > 0.0 else rules.pickup_interval
		s.next_at = maxf(s.next_at + interval, time)
		var old := item(s.item_uid)
		if old != null:
			items.erase(old)
		s.item_uid = -1
		if s.point.items.is_empty():
			continue
		var pick := StringName(s.point.items[rng.randi_range(0, s.point.items.size() - 1)])
		if not (rules.weapons.has(pick) or WeaponTable.GRENADES.has(pick) or pick == HEALTH_PACK or pick == BATTERY_PACK):
			push_warning("pickup point %s lists unknown item %s" % [s.point.name, pick])
			continue
		var it := place_item(pick, s.point.global_position, interval - rules.floor_lifetime_lead)
		# A map item sits where the map puts it; only dropped items fall.
		it.resting = true
		it.point = i
		s.item_uid = it.uid
		_emit({"type": &"item_spawn", "item": pick, "uid": it.uid, "pos": it.pos})


# --- geometry -----------------------------------------------------------------------------

## First terrain hit on the segment: {pos, normal, t} with t from 0 to 1, or {} for none.
func _terrain_hit(from: Vector2, to: Vector2) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 << (SimToy.TERRAIN_LAYER - 1))
	q.collide_with_areas = false
	var r := sim.get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {}
	var p: Vector2 = r.position
	return {"pos": p, "normal": r.normal, "t": from.distance_to(p) / from.distance_to(to)}


## First toy hit on the segment, skipping `shooter` and its teammates (US-06.4):
## {fighter, t, head}, or {} for none.
func _toy_hit(from: Vector2, to: Vector2, shooter: Fighter) -> Dictionary:
	var best := {}
	var best_t := INF
	for f in fighters:
		if not f.alive or f == shooter or (shooter != null and shooter.is_teammate(f)):
			continue
		for cs: CollisionShape2D in f.toy.hit_shapes():
			var centre := f.toy.position + cs.position
			var t := -1.0
			if cs.shape is CircleShape2D:
				t = segment_circle(from, to, centre, (cs.shape as CircleShape2D).radius)
			elif cs.shape is RectangleShape2D:
				var box := (cs.shape as RectangleShape2D).get_rect()
				box.position += centre
				t = segment_rect(from, to, box)
			if t >= 0.0 and t < best_t:
				best_t = t
				best = {"fighter": f, "t": t, "head": cs.name == &"Head"}
	return best


## Where the segment first touches the box, 0 to 1, or -1. A start inside counts as 0.
static func segment_rect(from: Vector2, to: Vector2, box: Rect2) -> float:
	var d := to - from
	var t0 := 0.0
	var t1 := 1.0
	for axis: int in [Vector2.AXIS_X, Vector2.AXIS_Y]:
		var lo := box.position[axis]
		var hi := box.end[axis]
		if is_zero_approx(d[axis]):
			if from[axis] < lo or from[axis] > hi:
				return -1.0
			continue
		var a := (lo - from[axis]) / d[axis]
		var b := (hi - from[axis]) / d[axis]
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 > t1:
			return -1.0
	return t0


## Where the segment first touches the circle, 0 to 1, or -1. A start inside counts as 0.
static func segment_circle(from: Vector2, to: Vector2, centre: Vector2, radius: float) -> float:
	var f := from - centre
	if f.length_squared() <= radius * radius:
		return 0.0
	var d := to - from
	var a := d.length_squared()
	if is_zero_approx(a):
		return -1.0
	var b := f.dot(d)
	var c := f.length_squared() - radius * radius
	var disc := b * b - a * c
	if disc < 0.0:
		return -1.0
	var t := (-b - sqrt(disc)) / a
	return t if t >= 0.0 and t <= 1.0 else -1.0


func _emit(e: Dictionary) -> void:
	e["tick"] = sim.tick
	events.append(e)
	event.emit(e)
