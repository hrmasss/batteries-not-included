extends "res://tests/bots/test_us36_bots_play.gd"
## US-36.1, US-36.4 on the art bedroom, the default map: every bots check of the blockout runs
## again here (its collision is the kit's, not a grid), plus the places on this map where bots
## used to get stuck.

const BEDROOM := MatchConfig.DEFAULT_MAP


func map_path() -> String:
	return BEDROOM


func _bedroom_sim() -> MatchSim:
	if sim != null and is_instance_valid(sim) and sim.get_parent() != null:
		sim.get_parent().remove_child(sim)
	sim = MatchSim.new()
	sim.setup(RulesetLoader.load_standard().ruleset, (load(BEDROOM) as PackedScene).instantiate())
	add_child(sim)
	autofree(sim)
	sim.start_combat(1)
	return sim


func test_bedroom_is_the_default_map() -> void:
	var cfg := MatchConfig.defaults(RulesetLoader.load_standard().ruleset)
	assert_eq(cfg.map_path, "res://maps/bedroom/bedroom.tscn")
	var paths: Array = MapList.all().map(func(m: Dictionary) -> String: return m.path)
	assert_has(paths, MatchConfig.BLOCKOUT_MAP, "the blockout stays a choice, for tests")


func test_no_sealed_pockets_every_spawn_and_pickup_reaches_every_other() -> void:
	# Under the bed and under the desk were closed boxes: a toy spawned there never got out.
	var s := _bedroom_sim()
	await wait_physics_frames(1)
	var level := s.rules.bots.get_level(s.rules.bots.order[0])
	var nav := NavGrid.build(s, level.nav_cell, level.air_cost)
	var spots: Array[Vector2] = []
	var names: Array[String] = []
	for p: SpawnPoint in s.map.spawn_points():
		spots.append(p.global_position + Vector2(0.0, s.rules.body_bottom))
		names.append("spawn " + p.name)
	for p: PickupPoint in s.map.pickup_points():
		spots.append(p.global_position + Vector2(0.0, s.rules.body_bottom))
		names.append("pickup " + p.name)
	for i in spots.size():
		var from := spots[0] if i != 0 else spots[1]
		assert_gt(nav.path(from, spots[i]).size(), 0, "%s is reachable" % names[i])


func test_a_toy_walks_out_from_under_the_bed_and_the_desk() -> void:
	for spot: Array in [["UnderBed", 830.0], ["UnderDesk", 1935.0]]:
		var s := _bedroom_sim()
		await wait_physics_frames(1)
		var index := -1
		for i in s.map.spawn_points().size():
			if s.map.spawn_points()[i].name == spot[0]:
				index = i
		assert_gt(index, -1, "%s spawn exists" % spot[0])
		var t := s.spawn_toy(index)
		s.run(roundi(3.0 / SimClock.TICK), {t.toy_id: InputIntent.make(Vector2(1, 0), true)})
		assert_gt(t.position.x, float(spot[1]), "%s: walking right leaves the space" % spot[0])
		assert_true(t.foot_contact, "%s: on its feet, nothing in the way" % spot[0])
