class_name Drills
extends RefCounted
## Measuring drills (US-37.6): scripted runs on a match that measure feel numbers the way a
## tuner would with a stopwatch. Tests use them to prove criteria; the tuning sandbox will show
## them. Each drill runs from the toy's current state and leaves the toy wherever it ends.

const MAX_SECONDS := 60.0
const UP := Vector2(0.0, 1.0)
const RIGHT := Vector2(1.0, 0.0)


static func _ticks(seconds: float) -> int:
	return roundi(seconds * SimClock.TICK_RATE)


static func _run(sim: MatchSim, toy: SimToy, intent: InputIntent, ticks: int) -> void:
	for i in ticks:
		sim.step({toy.toy_id: intent})


## Lets the toy settle on the ground with the stick let go.
static func settle(sim: MatchSim, toy: SimToy, seconds: float = 1.0) -> void:
	_run(sim, toy, InputIntent.idle(), _ticks(seconds))


## Holds the stick straight up from standing until the battery is empty. Returns the seconds
## spent thrusting (T-25 full-up flight).
static func full_up_flight(sim: MatchSim, toy: SimToy) -> float:
	var up := InputIntent.make(UP)
	var thrusting := 0
	for i in _ticks(MAX_SECONDS):
		sim.step({toy.toy_id: up})
		if toy.jetpack_on and toy.thrust > 0.0:
			thrusting += 1
		elif thrusting > 0:
			break
	return thrusting * SimClock.TICK


## Seconds from an empty battery to full, flying stopped, the stick let go.
static func refill_time(sim: MatchSim, toy: SimToy) -> float:
	var idle := InputIntent.idle()
	for i in _ticks(MAX_SECONDS):
		if toy.battery >= toy.battery_max:
			return i * SimClock.TICK
		sim.step({toy.toy_id: idle})
	return INF


## Holds the stick fully sideways for `seconds`; returns the highest sideways speed.
static func top_walk_speed(sim: MatchSim, toy: SimToy, seconds: float = 4.0, stick_x: float = 1.0) -> float:
	var walk := InputIntent.make(RIGHT * stick_x)
	var top := 0.0
	for i in _ticks(seconds):
		sim.step({toy.toy_id: walk})
		top = maxf(top, absf(toy.velocity.x))
	return top


## From walking at full speed, lets go; returns seconds until the toy is still (below 1 u/s).
static func stop_time(sim: MatchSim, toy: SimToy) -> float:
	top_walk_speed(sim, toy, 3.0)
	var idle := InputIntent.idle()
	for i in _ticks(MAX_SECONDS):
		if toy.speed() < 1.0:
			return i * SimClock.TICK
		sim.step({toy.toy_id: idle})
	return INF


## Taps the stick up for `hold` seconds, then lets go; returns how high the feet rose.
static func jump_height(sim: MatchSim, toy: SimToy, hold: float = 0.2) -> float:
	var start := toy.position.y
	var top := start
	var up := InputIntent.make(UP)
	var idle := InputIntent.idle()
	for i in _ticks(3.0):
		sim.step({toy.toy_id: up if i < _ticks(hold) else idle})
		top = minf(top, toy.position.y)
	return start - top
