class_name BotNames
extends RefCounted
## Names for bootcamp bots: toy-box names of our own. Cosmetic only.

const NAMES: PackedStringArray = [
	"Sprocket", "Button", "Corporal Crayon", "Dusty", "Major Marble", "Pip", "Rivet", "Tumble",
	"Captain Cork", "Bolt", "Sergeant Sock", "Wobble", "Domino", "Jinx", "Pogo", "Ziggy",
]


## `count` different names, picked by `seed_value`.
static func pick(count: int, seed_value: int) -> PackedStringArray:
	var pool := NAMES.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: PackedStringArray = []
	for k in count:
		if pool.is_empty():
			out.append("Bot %d" % (k + 1))
			continue
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out
