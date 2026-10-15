class_name SimClock
extends RefCounted
## The fixed clock the rules run on (rule A3, NF-12). Frames of any length go in; whole ticks
## come out. The same inputs give the same result at any frame rate.

## Ticks per second. Set by the build, not the ruleset: changing it changes nothing a player
## can feel, since every rate is per second.
const TICK_RATE := 60
const TICK := 1.0 / TICK_RATE
## A frame longer than this many ticks drops the rest, so a stall never snowballs.
const MAX_TICKS_PER_FRAME := 8

var _carry: float = 0.0


## Adds one frame of real time; returns how many ticks to run now.
func advance(frame_seconds: float) -> int:
	_carry += maxf(frame_seconds, 0.0)
	var ticks := int(floor(_carry * TICK_RATE + 1e-6))
	_carry -= ticks * TICK
	if _carry < 0.0:
		_carry = 0.0
	if ticks > MAX_TICKS_PER_FRAME:
		ticks = MAX_TICKS_PER_FRAME
		_carry = 0.0
	return ticks


## How far the clock is between the last tick and the next, 0 to 1. The view uses it to draw
## between two tick states.
func alpha() -> float:
	return clampf(_carry * TICK_RATE, 0.0, 1.0)


func reset() -> void:
	_carry = 0.0
