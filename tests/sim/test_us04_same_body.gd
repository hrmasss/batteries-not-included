extends GutTest
## US-04.1, US-04.2 and NF-12: one body for every toy; the same path at any frame rate.

const SECONDS := 10.0


## A scripted run in seconds: walk, jump, fly up, sideways, dive, let go. Changes sit on
## 1/30 s marks so every frame rate sees them on the same tick.
static func script() -> ScriptedInput:
	return ScriptedInput.from_steps([
		{"t": 0.0, "move": [0, 0], "held": false},
		{"t": 0.5, "move": [1, 0]},
		{"t": 1.5, "move": [0, 1]},
		{"t": 3.0, "move": [0.7, 0.7]},
		{"t": 4.5, "move": [-1, 0.2]},
		{"t": 6.0, "move": [0, -1]},
		{"t": 7.0, "move": [0, 0], "held": false},
		{"t": 8.0, "move": [-1, 0]},
		{"t": 9.0, "move": [0, -1]},
	])


## Runs the script with frames of `fps`, the way the view does: the clock turns frames into
## ticks and each tick reads the input the frame sampled.
func run_at(fps: float, toy_type: StringName = &"plastic_soldier") -> Array[Vector2]:
	var s := TestWorld.sim(self)
	var t := s.spawn_toy(0, toy_type)
	var clock := SimClock.new()
	var input := script()
	var path: Array[Vector2] = []
	var now := 0.0
	var frame := 1.0 / fps
	while now < SECONDS - 1e-9:
		now += frame
		var intent := input.intent_at(now - frame)
		for i in clock.advance(frame):
			s.step({t.toy_id: intent})
			if s.tick % SimClock.TICK_RATE == 0:
				path.append(t.position)
	path.append(t.position)
	# Free now: two maps in one physics space would touch each other's toys.
	s.free()
	return path


func test_us04_2_same_path_at_30_60_120_fps() -> void:
	var p60 := run_at(60.0)
	var p30 := run_at(30.0)
	var p120 := run_at(120.0)
	assert_eq(p60.size(), p30.size())
	assert_eq(p60.size(), p120.size())
	var worst := 0.0
	for i in p60.size():
		worst = maxf(worst, maxf(p60[i].distance_to(p30[i]), p60[i].distance_to(p120[i])))
	gut.p("largest gap between 30, 60 and 120 fps over %d s: %.6f u" % [SECONDS, worst])
	assert_lt(p60[-1].distance_to(p30[-1]), 1.0, "30 fps within 1 u after 10 s")
	assert_lt(p60[-1].distance_to(p120[-1]), 1.0, "120 fps within 1 u after 10 s")
	assert_gt(p60[0].distance_to(p60[-1]), 100.0, "the run actually moved")


func test_nf12_uneven_frames_give_the_same_path() -> void:
	var even := run_at(60.0)
	# Jittery frames: 5 to 40 ms, the same script.
	var s := TestWorld.sim(self)
	autofree(s)
	var t := s.spawn_toy(0)
	var clock := SimClock.new()
	var input := script()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var now := 0.0
	while s.tick < roundi(SECONDS * SimClock.TICK_RATE):
		var frame := rng.randf_range(0.005, 0.040)
		for i in clock.advance(frame):
			var tick_time := s.tick * SimClock.TICK
			s.step({t.toy_id: input.intent_at(tick_time)})
			if s.tick >= roundi(SECONDS * SimClock.TICK_RATE):
				break
		now += frame
	# Same intents per tick as 60 fps, so the path is the same.
	assert_lt(t.position.distance_to(even[-1]), 1.0)


func test_us04_1_every_toy_type_moves_the_same() -> void:
	var soldier := run_at(60.0, &"plastic_soldier")
	var plush := run_at(60.0, &"plush")
	var robot := run_at(60.0, &"tin_robot")
	for i in soldier.size():
		assert_eq(plush[i], soldier[i], "plush path tick %d" % i)
		assert_eq(robot[i], soldier[i], "robot path tick %d" % i)


func test_us04_1_every_toy_type_has_the_same_hitbox() -> void:
	var s := TestWorld.sim(self)
	autofree(s)
	var a := s.spawn_toy(0, &"plastic_soldier")
	var b := s.spawn_toy(0, &"plush")
	assert_eq(a.hit_bounds().size, b.hit_bounds().size)
	assert_eq(a.weight_factor(s.rules), b.weight_factor(s.rules))
	var shapes_a := a.hit_shapes().map(func(c: CollisionShape2D) -> Array: return [c.position, c.shape.get_rect()])
	var shapes_b := b.hit_shapes().map(func(c: CollisionShape2D) -> Array: return [c.position, c.shape.get_rect()])
	assert_eq(shapes_a, shapes_b)


func test_us04_1_toys_do_not_block_each_other() -> void:
	var s := TestWorld.sim(self)
	autofree(s)
	var a := s.spawn_toy(0)
	var b := s.spawn_toy(0)
	s.run(60)
	assert_almost_eq(a.position.x, b.position.x, 0.001, "two toys on one spot stay overlapped, as in the classic")
