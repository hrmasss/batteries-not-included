class_name Bot
extends RefCounted
## A computer-driven toy (US-36). It reads the match as a player would see it and hands the
## match server one `InputIntent` per tick, the same intent a touch screen makes. It never
## writes its toy's or anyone's state, so it has the same body, weapons, battery and rules as
## a player (T-98): no cheating on movement, battery or ammo.
##
## What it does, every tick:
## - Looks for enemies within sight with a clear line (T-95), and reacts only after one has
##   been in sight for its reaction time.
## - Turns its aim toward the target at a limited speed and stops inside a dead zone (T-96).
## - Fires in waits and bursts (T-97), throws frags at middle range, swings up close.
## - Moves: fights at a distance that suits its gun, takes pickups that help, falls back to
##   cover when hurt, chases where it last saw an enemy, otherwise wanders the map. Walks
##   where it can and flies where it must, and lands to refill when the battery runs low.
##
## Every number comes from its `BotSkill` or the ruleset. World space is y down; intent
## vectors are y up.

enum Goal { WANDER, FIGHT, ITEM, CHASE, RETREAT }

## Stick values a bot uses. Not tuning: they pick a stick position, like a thumb does.
const STICK_JUMP := Vector2(0.0, 1.0)
const STICK_LAND_DOWN := -0.25
## Squares and halves in the formulas below.
const TWO := 2.0
const HALF := 0.5
## Seconds a bot keeps pushing up to get free when stuck. Solver detail.
const UNSTICK_TIME := 0.6
## Least speed the flight controller counts on reaching, u/s. Solver detail.
const MIN_MISSING := 1.0
## Replan a path at least this often, s. Solver detail.
const REPLAN := 0.5

var fighter: Fighter
var skill: BotSkill
var sim: MatchSim
var combat: CombatSim
var nav: NavGrid
var rng := RandomNumberGenerator.new()

## The enemy being fought, or null.
var target: Fighter = null
var goal: Goal = Goal.WANDER
var goal_pos: Vector2 = Vector2.ZERO
## Times this bot found itself stuck and pushed free; for tests and the debug overlay.
var stuck_events: int = 0
## True while it saves the battery: no thrust until it refills (T-20 to T-23).
var resting: bool = false

## World-space aim angle, radians, y down.
var aim_angle: float = 0.0

# Sight: seconds each enemy has been in sight, and where and when each was last seen.
var _seen: Dictionary = {}
var _last_pos: Dictionary = {}
var _last_time: Dictionary = {}
var _visible: Dictionary = {}

var _look_left: float = 0.0
var _think_left: float = 0.0
var _wobble: float = 0.0
var _wobble_left: float = 0.0

# Fire rhythm (T-97).
var _rhythm_on: bool = false
var _bursting: bool = false
var _rhythm_left: float = 0.0
var _lost_for: float = 0.0
var _first: bool = true

var _grenade_left: float = 0.0
var _throw_dir: Vector2 = Vector2.ZERO
var _throw_left: float = 0.0

var _wander_left: float = 0.0
var _item_uid: int = -1
var _strafe: float = 0.0
var _strafe_left: float = 0.0

var _path := PackedVector2Array()
var _path_i: int = 0
var _path_goal: Vector2 = Vector2.INF
var _path_age: float = 0.0

var _stuck_from: Vector2 = Vector2.ZERO
var _stuck_left: float = 0.0
var _unstick_left: float = 0.0
var _unstick_side: float = 1.0

var _was_alive: bool = false
var _press: int = 0


func _init(f: Fighter, level: BotSkill, match_sim: MatchSim, grid: NavGrid, seed_value: int) -> void:
	fighter = f
	skill = level
	sim = match_sim
	combat = match_sim.combat
	nav = grid
	rng.seed = seed_value
	aim_angle = Vector2(f.toy.facing.x, -f.toy.facing.y).angle()


func id() -> int:
	return fighter.id()


## This tick's intent. Call once per tick, before the match steps.
func intent(dt: float) -> InputIntent:
	var i := InputIntent.new()
	if not fighter.alive:
		_was_alive = false
		target = null
		_seen.clear()
		_visible.clear()
		_path = PackedVector2Array()
		return i
	if not _was_alive:
		_on_spawn()
	_tick_timers(dt)
	_look_left -= dt
	if _look_left <= 0.0:
		_look_left += skill.look_interval
		_look()
	_think_left -= dt
	if _think_left <= 0.0:
		_think_left += skill.think_interval
		_think()
	_check_stuck(dt)
	_drive(i, dt)
	_aim(i, dt)
	_fight(i, dt)
	i.buttons = _press
	_press = 0
	return i


func _on_spawn() -> void:
	_was_alive = true
	aim_angle = Vector2(fighter.toy.facing.x, -fighter.toy.facing.y).angle()
	_rhythm_on = false
	_stuck_from = fighter.toy.position
	_stuck_left = skill.stuck_time
	_wander_left = 0.0
	_path_goal = Vector2.INF
	_think_left = 0.0
	_look_left = 0.0
	resting = false


func _tick_timers(dt: float) -> void:
	_grenade_left -= dt
	_throw_left -= dt
	_wander_left -= dt
	_strafe_left -= dt
	_path_age += dt
	_unstick_left -= dt
	_wobble_left -= dt
	if _wobble_left <= 0.0:
		_wobble_left = skill.aim_wobble
		_wobble = deg_to_rad(rng.randf_range(-skill.aim_error, skill.aim_error))


# --- seeing -----------------------------------------------------------------------------

func eye() -> Vector2:
	return fighter.toy.position + Vector2(0.0, -skill.eye_height)


## T-95: enemies inside sight range with a clear line; one becomes the target only after it
## has been in sight for the reaction time.
func _look() -> void:
	var me := eye()
	var now := combat.time
	_visible.clear()
	for other in combat.fighters:
		if other == fighter or not other.alive or fighter.is_teammate(other):
			_seen.erase(other.id())
			continue
		var at := other.toy.position
		if me.distance_to(at) > skill.sight or not nav.sees(me, at):
			_seen.erase(other.id())
			continue
		_seen[other.id()] = float(_seen.get(other.id(), 0.0)) + skill.look_interval
		_last_pos[other.id()] = at
		_last_time[other.id()] = now
		_visible[other.id()] = true
	# Keep the target while it stays in sight; otherwise the nearest one reacted to.
	if target != null and (not target.alive or not _visible.has(target.id())):
		target = null
	if target == null:
		var best_d := INF
		for other in combat.fighters:
			if _visible.has(other.id()) and float(_seen[other.id()]) >= skill.reaction:
				var d := me.distance_to(other.toy.position)
				if d < best_d:
					best_d = d
					target = other


func sees_target() -> bool:
	return target != null and _visible.has(target.id())


# --- deciding -----------------------------------------------------------------------------

func _think() -> void:
	var t := fighter.toy
	var rules := sim.rules
	var health := t.health / rules.max_health
	var battery := t.battery / t.battery_max if t.battery_max > 0.0 else 1.0
	if rules.batteries_included:
		resting = false
	elif not resting and battery < skill.battery_low:
		resting = true
	elif resting and battery >= skill.battery_resume:
		resting = false

	_manage_weapons()

	var item := _best_item(health)
	if target != null:
		_lost_for = 0.0
		if health < skill.retreat_health and item == null:
			if goal != Goal.RETREAT:
				_set_goal(Goal.RETREAT, _cover_from(target.toy.position))
		elif item != null and item.item == CombatSim.HEALTH_PACK and health < skill.retreat_health:
			_go_item(item)
		else:
			_set_goal(Goal.FIGHT, _fight_spot())
		return
	_lost_for += skill.think_interval
	if goal == Goal.RETREAT and health < skill.want_health and _lost_for < skill.memory:
		return
	if item != null:
		_go_item(item)
		return
	var last := _last_enemy()
	if not last.is_empty():
		_set_goal(Goal.CHASE, last.pos)
		return
	if goal != Goal.WANDER or _wander_left <= 0.0 or t.position.distance_to(goal_pos) < skill.reach:
		_wander()


func _set_goal(g: Goal, at: Vector2) -> void:
	goal = g
	goal_pos = at
	if g != Goal.ITEM:
		_item_uid = -1


func _wander() -> void:
	_wander_left = rng.randf_range(skill.wander_min, skill.wander_max)
	var spots: Array[Vector2] = []
	for p: SpawnPoint in sim.map.spawn_points():
		spots.append(p.global_position + Vector2(0.0, sim.rules.body_bottom - SimToy.SAFE_MARGIN))
	for p: PickupPoint in sim.map.pickup_points():
		spots.append(p.global_position)
	var at: Vector2
	if spots.is_empty() or rng.randf() < HALF:
		at = nav.random_floor(rng)
	else:
		at = spots[rng.randi_range(0, spots.size() - 1)]
	_set_goal(Goal.WANDER, at)


func _go_item(it: CombatSim.FloorItem) -> void:
	_set_goal(Goal.ITEM, it.pos)
	_item_uid = it.uid


## The most recently seen enemy still in mind: {pos}, or {} when none.
func _last_enemy() -> Dictionary:
	var best := {}
	var best_t := -INF
	for k: int in _last_time:
		var when: float = _last_time[k]
		if combat.time - when <= skill.memory and when > best_t:
			var f := combat.fighter(k)
			if f != null and f.alive:
				best_t = when
				best = {"pos": _last_pos[k]}
	if not best.is_empty() and fighter.toy.position.distance_to(best.pos) < skill.reach:
		_last_time.clear()
		return {}
	return best


## Where to stand while fighting: at a distance that suits the held gun, a little above the
## target, sliding side to side.
func _fight_spot() -> Vector2:
	var me := fighter.toy.position
	var them := target.toy.position
	var w := fighter.main_weapon()
	var want := skill.melee_range
	if w != null and w.def.shoots() and _has_ammo(w):
		var reach := w.def.range if w.def.kind == WeaponDef.BULLET else skill.fight_max
		want = clampf(reach * skill.fight_share, skill.fight_min, skill.fight_max)
	if _strafe_left <= 0.0:
		_strafe_left = rng.randf_range(skill.strafe_min, skill.strafe_max)
		_strafe = rng.randf_range(-skill.strafe, skill.strafe)
	var away := (me - them).normalized() if not me.is_equal_approx(them) else Vector2.LEFT
	var spot := them + away * want + Vector2(_strafe, -absf(_strafe))
	var c := nav.free_near(spot)
	return nav.point(c) if c.x >= 0 else me


## Cover: a known place out of the threat's sight, not toward it, nearest first (US-36.4).
func _cover_from(threat: Vector2) -> Vector2:
	var me := fighter.toy.position
	var best := me
	var best_d := INF
	for k in int(skill.cover_tries):
		var p := nav.random_floor(rng)
		if nav.sees(threat, p) or p.distance_to(threat) < me.distance_to(threat):
			continue
		var d := me.distance_to(p)
		if d < best_d:
			best_d = d
			best = p
	if best == me:
		best = me + (me - threat).normalized() * skill.fight_max
	return best


## The pickup worth going for now, or null: a health pack when hurt, a battery pack when low,
## frags under the cap, a better gun. Only items the bot can see.
func _best_item(health: float) -> CombatSim.FloorItem:
	var t := fighter.toy
	var rules := sim.rules
	var best: CombatSim.FloorItem = null
	var best_score := 0.0
	for it in combat.items:
		var d := t.position.distance_to(it.pos)
		if d > skill.sight or not nav.sees(eye(), it.pos):
			continue
		var value := 0.0
		if it.item == CombatSim.HEALTH_PACK:
			value = 1.0 - health if health < skill.want_health else 0.0
		elif it.item == CombatSim.BATTERY_PACK:
			value = 1.0 - t.battery / maxf(t.battery_max, MIN_MISSING) if not rules.batteries_included else 0.0
		elif WeaponTable.GRENADES.has(it.item):
			value = skill.frag_value if fighter.grenade_count() < rules.grenade_cap else 0.0
		elif it.weapon != null:
			value = _gun_gain(it.weapon)
		if value <= 0.0:
			continue
		var score := value * skill.sight / (d + skill.sight)
		if score > best_score:
			best_score = score
			best = it
	return best


## How much better a floor gun is than what the bot would give up for it, 0 for no better.
func _gun_gain(w: WeaponItem) -> float:
	if not _has_ammo(w):
		return 0.0
	if fighter.weapons.size() < Fighter.SLOTS:
		return 1.0
	var held := fighter.main_weapon()
	var mine := gun_value(held) if held != null and _has_ammo(held) else 0.0
	var theirs := gun_value(w)
	return clampf((theirs - mine) / theirs, 0.0, 1.0) if theirs > 0.0 else 0.0


## A gun's worth to a bot: damage per second at the muzzle.
func gun_value(w: WeaponItem) -> float:
	var d := w.def
	var per_shot := d.damage * d.pellets if d.kind != WeaponDef.ROCKET else sim.rules.rocket_direct_damage
	return per_shot * d.burst / maxf(d.interval, SimClock.TICK)


func _has_ammo(w: WeaponItem) -> bool:
	return sim.rules.batteries_included or w.mag > 0 or w.reserve > 0


func _manage_weapons() -> void:
	var w := fighter.main_weapon()
	if w == null:
		return
	var other: WeaponItem = null
	if fighter.weapons.size() == Fighter.SLOTS:
		other = fighter.weapons[1 - fighter.held]
	if other != null and not fighter.is_dual():
		var swap := not _has_ammo(w) and _has_ammo(other)
		swap = swap or (_has_ammo(other) and gun_value(other) > gun_value(w) and not w.reloading())
		if swap:
			_press |= InputIntent.Act.SWITCH
			return
	if target == null and w.def.shoots() and w.can_reload() and w.mag < w.def.mag * skill.reload_share:
		_press |= InputIntent.Act.RELOAD
	# Take an offered gun that beats the held one.
	if fighter.offer >= 0:
		var it := combat.item(fighter.offer)
		if it != null and it.weapon != null and _gun_gain(it.weapon) > 0.0:
			_press |= InputIntent.Act.PICK_UP


# --- moving -------------------------------------------------------------------------------

func _check_stuck(dt: float) -> void:
	_stuck_left -= dt
	if _stuck_left > 0.0:
		return
	_stuck_left = skill.stuck_time
	var p := fighter.toy.position
	var moved := p.distance_to(_stuck_from)
	_stuck_from = p
	var trying := goal != Goal.FIGHT and p.distance_to(goal_pos) > skill.reach and not resting
	if trying and moved < skill.stuck_distance:
		stuck_events += 1
		_unstick_left = UNSTICK_TIME
		_unstick_side = -_unstick_side
		_wander()


func _drive(i: InputIntent, dt: float) -> void:
	var t := fighter.toy
	if _unstick_left > 0.0 and not resting:
		i.move = Vector2(_unstick_side, STICK_JUMP.y).normalized()
		i.move_held = true
		return
	var dest := goal_pos
	var wp := _waypoint(dest)
	var to := wp - t.position
	if t.position.distance_to(dest) < skill.reach:
		if goal == Goal.FIGHT:
			_hold(i)
		# Else let go: the brake stops the toy and the battery refills.
		return
	if resting:
		# Saving the battery: walk on floors, fall from the air.
		if t.foot_contact:
			_walk(i, to)
		return
	var above := -to.y >= skill.reach
	var landing := t.jetpack_on and nav.is_floor(nav.cell_of(wp))
	if not above and ((t.foot_contact and not t.jetpack_on) or landing):
		_walk(i, to)
		return
	_fly(i, to, t.position.distance_to(dest), sim.rules)


func _hold(i: InputIntent) -> void:
	var t := fighter.toy
	if t.jetpack_on and not t.foot_contact and not resting:
		# Hover in place: hold the stick, let the jetpack hold against the light flying gravity.
		var a := Vector2(-t.velocity.x, t.velocity.y) * skill.steer_gain + Vector2(0.0, sim.rules.fly_gravity)
		_thrust(i, a)
	# Else let go: the brake stops the toy and the battery refills.


func _walk(i: InputIntent, to: Vector2) -> void:
	var t := fighter.toy
	if absf(to.x) < skill.reach * HALF:
		return
	var side := signf(to.x)
	i.move_held = true
	i.move = Vector2(side, STICK_LAND_DOWN).normalized()
	# A wall at the feet: jump it (the jetpack takes over if it is tall).
	if not nav.clear(t.position, t.position + Vector2(side * skill.reach, 0.0)) and not resting:
		i.move = Vector2(side * STICK_JUMP.x, STICK_JUMP.y)


func _fly(i: InputIntent, to: Vector2, to_goal: float, rules: Ruleset) -> void:
	var t := fighter.toy
	i.move_held = true
	if not t.jetpack_on:
		# Jump, then keep pushing up until the jetpack takes over (T-13, T-14).
		var side := clampf(to.x / skill.arrive, -rules.engage_up, rules.engage_up)
		i.move = Vector2(side, STICK_JUMP.y).normalized()
		return
	var weight := t.weight_factor(rules)
	var cruise := ToyMotor.fly_target(rules, weight) * skill.cruise_share
	var speed := cruise * clampf(to_goal / skill.arrive, skill.reach / skill.arrive, 1.0)
	var dir_up := Vector2(to.x, -to.y).normalized() if to.length() > 0.0 else Vector2.ZERO
	var want := dir_up * speed
	var v := Vector2(t.velocity.x, -t.velocity.y)
	# Steer toward the wanted velocity, hold against flying gravity and make up for drag (T-7).
	var a := (want - v) * skill.steer_gain + Vector2(0.0, rules.fly_gravity) - want * log(rules.speed_kept_per_second)
	_thrust(i, a)


## Sets the stick so the jetpack pushes as close to `a` (u/s², y up) as it can (T-5, T-6).
func _thrust(i: InputIntent, a: Vector2) -> void:
	var t := fighter.toy
	var rules := sim.rules
	i.move_held = true
	if a.length() <= 0.0:
		return
	var dir := a.normalized()
	var weight := t.weight_factor(rules)
	var v := Vector2(t.velocity.x, -t.velocity.y)
	var missing := maxf(ToyMotor.fly_target(rules, weight) - v.dot(dir), MIN_MISSING)
	var per_deflection := ToyMotor.fly_rate(1.0, rules, weight) * missing
	i.move = dir * clampf(a.length() / per_deflection, 0.0, 1.0)


## The next point to head for on the way to `dest`: straight there when the way is clear,
## else along a grid path, as far ahead as a straight line reaches.
func _waypoint(dest: Vector2) -> Vector2:
	var p := fighter.toy.position
	if nav.clear(p, dest):
		_path = PackedVector2Array()
		return dest
	if _path.is_empty() or _path_age > REPLAN or _path_goal.distance_to(dest) > skill.reach:
		_path = nav.path(p, dest)
		_path_i = 0
		_path_goal = dest
		_path_age = 0.0
	if _path.is_empty():
		return dest
	while _path_i < _path.size() - 1 and p.distance_to(_path[_path_i]) < skill.reach:
		_path_i += 1
	var best := _path_i
	for k in range(_path_i + 1, mini(_path.size(), _path_i + NavGrid.LOOK_AHEAD)):
		if nav.clear(p, _path[k]):
			best = k
	return _path[best]


# --- aiming and fighting ------------------------------------------------------------------

## T-96: the aim turns toward what the bot wants to hit by 1 + gap/20 degrees a step at the
## classic's rate (turn_rate + turn_gain × gap per second), and stops inside the dead zone.
func _aim(i: InputIntent, dt: float) -> void:
	var t := fighter.toy
	var want := aim_angle
	if _throw_left > 0.0:
		want = _throw_dir.angle()
	elif target != null:
		want = _aim_point().angle_to_point(t.position) + PI + _wobble
	elif t.velocity.length() > skill.reach:
		want = t.velocity.angle()
	var gap := rad_to_deg(angle_difference(aim_angle, want))
	if absf(gap) > skill.aim_dead_zone:
		var step := (skill.turn_rate + skill.turn_gain * absf(gap)) * dt
		aim_angle += deg_to_rad(signf(gap) * minf(step, absf(gap)))
	var d := Vector2.from_angle(aim_angle)
	i.aim = Vector2(d.x, -d.y)


## Where to aim at the target: its body, led by its velocity over the bullet's flight.
func _aim_point() -> Vector2:
	var at := target.toy.position
	var w := fighter.main_weapon()
	if w != null and w.def.bullet_speed > 0.0 and skill.lead > 0.0:
		var flight := fighter.toy.position.distance_to(at) / w.def.bullet_speed
		at += target.toy.velocity * flight * skill.lead
	return at


## How far off the aim is from the target, degrees.
func aim_gap() -> float:
	if target == null:
		return INF
	var want := _aim_point().angle_to_point(fighter.toy.position) + PI
	return absf(rad_to_deg(angle_difference(aim_angle, want)))


func _fight(i: InputIntent, dt: float) -> void:
	_rhythm(dt)
	if target == null:
		return
	var me := fighter.toy.position
	var them := target.toy.position
	var d := me.distance_to(them)
	var w := fighter.main_weapon()
	var seen := sees_target()
	# Up close: swing (US-09).
	if seen and d < skill.melee_range + sim.rules.body_width and fighter.swing_left <= 0.0:
		_press |= InputIntent.Act.MELEE
	# Frags at middle range, never onto a teammate (US-12, blasts hurt everyone).
	if _throw_left > 0.0:
		var off := rad_to_deg(absf(angle_difference(aim_angle, _throw_dir.angle())))
		if off < skill.fire_cone:
			_press |= InputIntent.Act.GRENADE
			_throw_left = 0.0
			_grenade_left = skill.grenade_cooldown
	elif seen and _grenade_left <= 0.0 and fighter.grenade_count() > 0 and d > skill.grenade_min and d < skill.grenade_max and not _mate_near(them):
		var dir := _throw_solution(them)
		if dir != Vector2.ZERO:
			_throw_dir = dir
			_throw_left = skill.throw_aim_time
			_grenade_left = skill.grenade_cooldown
	# Fire in the rhythm, with the aim on the target and the target in range (T-97).
	if seen and _bursting and w != null and w.def.shoots() and _has_ammo(w) and _throw_left <= 0.0:
		var reach := w.def.range if w.def.kind == WeaponDef.BULLET else sim.rules.rocket_speed_cap * sim.rules.rocket_life
		if d < reach and aim_gap() < skill.fire_cone:
			i.fire = true


## T-97: the first wait and burst, then waits and bursts at random. Starts on a new target and
## starts over once every enemy is out of mind.
func _rhythm(dt: float) -> void:
	if target == null:
		if _lost_for > skill.memory:
			_rhythm_on = false
			_bursting = false
		return
	if not _rhythm_on:
		_rhythm_on = true
		_bursting = false
		_rhythm_left = skill.first_wait
		_first = true
	_rhythm_left -= dt
	if _rhythm_left > 0.0:
		return
	_bursting = not _bursting
	if _bursting:
		_rhythm_left = skill.first_burst if _first else rng.randf_range(skill.burst_min, skill.burst_max)
		_first = false
	else:
		_rhythm_left = rng.randf_range(skill.wait_min, skill.wait_max)


func _mate_near(at: Vector2) -> bool:
	for other in combat.fighters:
		if other.alive and fighter.is_teammate(other) and other.toy.position.distance_to(at) < skill.grenade_mate_gap:
			return true
	return false


## The low throw that lands a frag on `at`, as a world-space unit vector, or zero for none.
func _throw_solution(at: Vector2) -> Vector2:
	var rules := sim.rules
	var v := rules.throw_speed
	var g := rules.frag_gravity * sim.map.item_gravity
	var me := fighter.toy.position
	var dx := absf(at.x - me.x)
	var up := me.y - at.y
	if g <= 0.0 or dx <= 0.0:
		return (at - me).normalized()
	var disc := v * v * v * v - g * (g * dx * dx + TWO * up * v * v)
	if disc < 0.0:
		return Vector2.ZERO
	var angle := atan((v * v - sqrt(disc)) / (g * dx))
	return Vector2(signf(at.x - me.x) * cos(angle), -sin(angle))
