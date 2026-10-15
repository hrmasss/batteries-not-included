class_name WeaponItem
extends RefCounted
## One weapon that exists in the match: carried by a toy or lying on the floor. It keeps its
## own magazine, reserve and timers, so a dropped gun keeps its ammo (US-07.3, US-07.6).

var def: WeaponDef
var mag: int = 0
var reserve: int = 0
## Seconds until the next round may go. Below zero while the trigger is held means rounds owed
## this tick, so the fire rate holds at any interval (US-05.3).
var cooldown: float = 0.0
## Seconds left on a reload; 0 when not reloading.
var reload_left: float = 0.0
## Rounds left in the burst under way (T-50 burst kind).
var burst_left: int = 0
## Spin-up held so far, s (T-50 spin-up kind).
var spin: float = 0.0


static func fresh(d: WeaponDef) -> WeaponItem:
	var w := WeaponItem.new()
	w.def = d
	w.mag = d.mag
	w.reserve = d.start_reserve
	return w


func id() -> StringName:
	return def.id


func reloading() -> bool:
	return reload_left > 0.0


func is_empty() -> bool:
	return mag + reserve <= 0


func can_reload() -> bool:
	return def.shoots() and mag < def.mag and reserve > 0 and not reloading()


## US-05.5: a reload takes the weapon's reload time and moves what fits from reserve.
func start_reload() -> bool:
	if not can_reload():
		return false
	burst_left = 0
	reload_left = def.reload
	if reload_left <= 0.0:
		_finish_reload()
	return true


func cancel_reload() -> void:
	reload_left = 0.0


func _finish_reload() -> void:
	reload_left = 0.0
	var moved := mini(def.mag - mag, reserve)
	mag += moved
	reserve -= moved


## Advances one tick and returns how many rounds leave the muzzle. `trigger` is the fire rule
## (US-05.2); `infinite` keeps the magazine full (Batteries Included).
func step(dt: float, trigger: bool, infinite: bool) -> int:
	if reloading():
		reload_left -= dt
		if reload_left <= 0.0:
			_finish_reload()
	if not def.shoots():
		return 0
	if def.spin_up > 0.0:
		spin = clampf(spin + (dt if trigger else -dt), 0.0, def.spin_up)
	cooldown -= dt
	var shots := 0
	while true:
		if burst_left == 0:
			var spun := def.spin_up <= 0.0 or spin >= def.spin_up
			if not (trigger and spun and cooldown <= 0.0 and mag > 0 and not reloading()):
				break
			burst_left = def.burst
		if cooldown > 0.0 or reloading():
			break
		if mag <= 0:
			burst_left = 0
			break
		shots += 1
		if not infinite:
			mag -= 1
		burst_left -= 1
		var wait := def.burst_gap if burst_left > 0 else maxf(def.interval - def.burst_gap * (def.burst - 1), 0.0)
		cooldown += wait
		if wait <= 0.0:
			cooldown = 0.0
			break
	if not trigger and burst_left == 0:
		cooldown = maxf(cooldown, 0.0)
	# US-05.5: an empty magazine with reserve left reloads by itself.
	if mag == 0 and burst_left == 0:
		start_reload()
	return shots


func copy() -> WeaponItem:
	var w := WeaponItem.new()
	w.def = def
	w.mag = mag
	w.reserve = reserve
	return w
