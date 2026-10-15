extends CombatTest
## The art in the game: the soldier rig, weapons at the grip, thrust, lean, faces, team marks,
## the pop, and the bedroom map built from the kit. Criteria checked by review are proved by
## the screenshots; these tests hold the parts code can check.

const PX := 1.0 / ArtAtlas.AUTHOR_PX_PER_U


func _fighter(weapon_ids: Array = [&"assault_rifle"], aim: Vector2 = Vector2.RIGHT) -> Fighter:
	make()
	var f := add(400.0, 1)
	f.weapons.clear()
	for id: StringName in weapon_ids:
		f.weapons.append(WeaponItem.fresh(rules.weapons.get_def(id)))
	f.held = 0
	f.aim = aim.normalized()
	return f


func _settle(anim: ToyAnimator, f: Fighter, frames: int = 40) -> ToyAnimator.Frame:
	var fr: ToyAnimator.Frame
	for i in frames:
		fr = anim.update(f.toy, f, f.toy.velocity, 1.0 / 60.0)
	return fr


func _fist(anim: ToyAnimator, fr: ToyAnimator.Frame, side: String) -> Vector2:
	var rig := anim.rig
	var fore: Transform2D = fr.parts[rig.index[StringName(side + "_forearm")]]
	return fore * ToyRig._v(rig.sockets.weapon_grip.pos)


func _grip_of(fr: ToyAnimator.Frame, weapon_id: StringName = &"") -> Vector2:
	# The weapon items carry their image transforms; the grip is the grip point in that image.
	for it: Array in fr.items:
		if it[3] == &"weapon" and (weapon_id == &"" or it[0] == ArtLibrary.weapon_piece(weapon_id)):
			var id := String(it[0]).get_file()
			var w := ArtLibrary.weapon(StringName(id))
			return (it[1] as Transform2D) * ArtLibrary.weapon_grip(w)
	return Vector2.INF


func test_atlas_holds_every_piece_the_game_draws() -> void:
	var a := ArtLibrary.actors()
	for f in ArtLibrary.soldier_files():
		assert_true(a.has(StringName(ArtLibrary.SOLDIER + f.get_basename())), "soldier %s" % f)
	for id: String in ArtLibrary.weapons():
		assert_true(a.has(ArtLibrary.weapon_piece(StringName(id))), "weapon %s" % id)
	for id: String in ArtLibrary.fx():
		assert_true(a.has(ArtLibrary.fx_piece(id)), "effect %s" % id)
	for id: String in ArtLibrary.pickups():
		assert_true(a.has(StringName("pickups/" + id)), "pickup %s" % id)
	var size := a.texture.get_size()
	assert_lte(maxf(size.x, size.y), 4096.0, "fits a phone's texture limit")
	for back in [false, true]:
		var k := ArtLibrary.bedroom(back)
		assert_lte(maxf(k.texture.get_size().x, k.texture.get_size().y), 4096.0, "bedroom sheet fits")
	gut.p("actors %s in %d ms, bedroom %s in %d ms" % [size, a.build_ms, ArtLibrary.bedroom(false).texture.get_size(), ArtLibrary.bedroom(false).build_ms])


func test_atlas_sizes_are_author_px() -> void:
	var a := ArtLibrary.actors()
	var rig := ArtLibrary.rig()
	for p: Dictionary in rig.parts:
		var got := a.size_of(StringName(ArtLibrary.SOLDIER + String(p.file).get_basename()))
		assert_almost_eq(got.x, float(p.size[0]), 1.0 / ArtAtlas.texels_per_u * 8.0 + 0.01, "%s width" % p.name)


func test_us11_5_every_weapon_in_the_table_has_art() -> void:
	make()
	for id in rules.weapons.ids():
		assert_false(ArtLibrary.weapon(id).is_empty(), "art for %s" % id)


func test_us11_5_trigger_hand_holds_the_grip_at_every_aim() -> void:
	for deg in [-80, -45, 0, 30, 70]:
		for side in [1.0, -1.0]:
			var aim := Vector2.from_angle(deg_to_rad(deg))
			aim.x *= side
			var f := _fighter([&"assault_rifle"], aim)
			var anim := ToyAnimator.new(ToyRig.soldier(), rules)
			var fr := _settle(anim, f)
			var grip := _grip_of(fr, &"assault_rifle")
			assert_lt(_fist(anim, fr, "near").distance_to(grip), 1.5, "near fist on the grip, aim %d side %d" % [deg, side])


func test_us11_5_two_handed_guns_take_the_support_hand() -> void:
	var f := _fighter([&"assault_rifle"])
	var anim := ToyAnimator.new(ToyRig.soldier(), rules)
	var fr := _settle(anim, f)
	var w := ArtLibrary.weapon(&"assault_rifle")
	var wxf: Transform2D
	for it: Array in fr.items:
		if it[3] == &"weapon":
			wxf = it[1]
	var support := wxf * ArtLibrary.weapon_support(w)
	assert_lt(_fist(anim, fr, "far").distance_to(support), 1.5, "far fist on the fore grip")


func test_us11_5_muzzle_points_along_the_aim() -> void:
	for a in [Vector2(1, 0), Vector2(1, -1), Vector2(-1, 0.4), Vector2(-0.3, -1)]:
		var f := _fighter([&"pistol"], a)
		var anim := ToyAnimator.new(ToyRig.soldier(), rules)
		var fr := _settle(anim, f)
		assert_eq(fr.muzzles.size(), 1)
		assert_almost_eq(fr.muzzles[0].x.normalized().dot(a.normalized()), 1.0, 0.01, "barrel along %s" % a)


func test_us11_5_dual_guns_and_a_handless_float() -> void:
	var f := _fighter([&"pistol", &"uzi"])
	assert_true(f.is_dual())
	var anim := ToyAnimator.new(ToyRig.soldier(), rules)
	var fr := _settle(anim, f)
	assert_eq(fr.muzzles.size(), 2, "both guns drawn")
	assert_lt(_fist(anim, fr, "far").distance_to(_grip_of(fr, &"uzi")), 1.5, "off hand holds the second gun")
	var floater := ToyAnimator.new(ToyRig.soldier(), rules)
	floater.handless = true
	var fr2 := _settle(floater, _fighter([&"smg"]))
	assert_eq(fr2.muzzles.size(), 1, "the gun floats beside a handless toy")
	assert_gt(_fist(floater, fr2, "near").distance_to(_grip_of(fr2)), 5.0, "and no hand holds it")


func test_us03_4_lean_is_t17_between_facing_and_stick() -> void:
	make()
	var t := add(400.0).toy
	t.stick = Vector2(1, 0)
	t.stick_held = true
	var w := rules.lean_facing_ground
	var want := Vector2.UP.angle_to((Vector2.UP * w + Vector2.RIGHT * (1.0 - w)).normalized())
	assert_almost_eq(ToyAnimator.lean_target(t, rules), minf(want, ToyAnimator.MAX_LEAN), 0.001, "ground weights")
	t.jetpack_on = true
	t.battery = 10.0
	var wf := rules.lean_facing_flying
	var want_f := Vector2.UP.angle_to((Vector2.UP * wf + Vector2.RIGHT * (1.0 - wf)).normalized())
	assert_almost_eq(ToyAnimator.lean_target(t, rules), want_f, 0.001, "flying weights")
	t.stick = Vector2.ZERO
	t.stick_held = false
	assert_eq(ToyAnimator.lean_target(t, rules), 0.0, "upright with the thumb off")


func test_us03_1_thrust_leaves_both_nozzles_against_the_push() -> void:
	var f := _fighter()
	var t := f.toy
	t.stick = Vector2(0.6, 0.8)
	t.stick_held = true
	t.thrust = 1.0
	var anim := ToyAnimator.new(ToyRig.soldier(), rules)
	var fr := _settle(anim, f)
	assert_eq(fr.nozzles.size(), 2, "two battery nozzles")
	assert_almost_eq(fr.thrust_dir.dot(Vector2(-0.6, 0.8)), 1.0, 0.001, "thrust points away from the stick (world, y down)")
	for n in fr.nozzles:
		assert_lt(n.y, -rules.body_bottom, "nozzles sit above the feet")


func test_us41_2_the_face_acts() -> void:
	var f := _fighter()
	var anim := ToyAnimator.new(ToyRig.soldier(), rules)
	assert_eq(_settle(anim, f, 2).face, &"determined", "calm on the ground")
	anim.flinch(f.toy.position.x + 40.0, f.toy.position.x)
	assert_eq(_settle(anim, f, 2).face, &"hurt", "hurt when hit")
	_settle(anim, f, 60)
	f.toy.jetpack_on = true
	f.toy.stick = Vector2(0, 1)
	f.toy.stick_held = true
	f.toy.battery = 10.0
	f.toy.thrust = 1.0
	assert_eq(_settle(anim, f, 2).face, &"cocky", "cocky in flight")
	f.toy.health = rules.max_health * 0.1
	assert_eq(_settle(anim, f, 2).face, &"shocked", "shocked when nearly popped")


func test_us26_1_us26_2_team_marks_differ_by_colour_and_pattern() -> void:
	var colours := {}
	var patterns := {}
	for team in range(1, 5):
		colours[TeamLook.battery_color(team).to_html()] = true
		patterns[TeamLook.pattern_piece(team)] = true
		assert_ne(TeamLook.outline_color(team), TeamLook.outline_color(Fighter.NO_TEAM))
	assert_eq(colours.size(), 4, "four team colours")
	assert_eq(patterns.size(), 4, "four patterns: plain, stripes, dots, chevrons")
	var lightness := []
	for team in range(1, 5):
		lightness.append(snappedf(TeamLook.battery_color(team).get_luminance(), 0.05))
	assert_gt(lightness.size(), 2)
	assert_eq(TeamLook.pattern_piece(Fighter.NO_TEAM), &"baked", "free-for-all keeps the copper top")
	assert_true(ArtLibrary.actors().has(TeamLook.baked_piece(Fighter.NO_TEAM)))
	for team in range(2, 5):
		assert_true(ArtLibrary.actors().has(TeamLook.pattern_piece(team)), "pattern art for team %d" % team)


func test_t18_the_art_never_changes_the_hitbox() -> void:
	make()
	var f := add(400.0, 1)
	var before := f.toy.hit_bounds()
	var v := ToyView.new(f.toy, rules, combat)
	add_child_autofree(v)
	for i in 10:
		v.sync(1.0, 1.0 / 60.0)
	assert_eq(f.toy.hit_bounds(), before)


func test_us15_1_a_pop_throws_the_rigs_own_parts_and_says_pop() -> void:
	make()
	var f := add(400.0, 1)
	var v := ToyView.new(f.toy, rules, combat)
	add_child_autofree(v)
	v.sync(1.0, 1.0 / 60.0)
	var field := FxField.of(v)
	field.particles.clear()
	combat.event.emit({"type": &"pop", "toy": f.id(), "killer": 0, "weapon": &"pistol", "credit": 0, "pos": f.toy.position})
	var pieces := {}
	for p in field.particles:
		pieces[p.piece] = true
	assert_true(pieces.has(ArtLibrary.fx_piece("pop_text")), "POP!")
	assert_true(pieces.has(ArtLibrary.fx_piece("pop_snap")), "snaps at the joints")
	assert_true(pieces.has(StringName(ArtLibrary.SOLDIER + "helmet")), "the helmet flies")
	assert_true(pieces.has(StringName(ArtLibrary.SOLDIER + "face_shocked")), "the face is shocked")
	var helmet_up := false
	for p in field.particles:
		if p.piece == StringName(ArtLibrary.SOLDIER + "helmet"):
			helmet_up = p.vel.y < -300.0
	assert_true(helmet_up, "the helmet goes up")


func test_us38_4_bedroom_collision_is_the_kit_collision() -> void:
	var m: GameMap = load("res://maps/bedroom/bedroom.tscn").instantiate()
	autofree(m)
	var kit := ArtLibrary.kit()
	var want := 0
	var polys := []
	for p in m.get_node("Props").get_children():
		var prop := p as KitProp
		var xf := Transform2D(0.0, prop.position) * KitProp.image_xf_for(prop.piece, prop.flip)
		for c: Dictionary in kit[prop.piece].get("collision", []):
			want += 1
			var poly := PackedVector2Array()
			for pt: Array in c.poly:
				poly.append(xf * Vector2(float(pt[0]), float(pt[1])))
			polys.append(poly)
	var got := []
	for c in m.get_node("Terrain").get_children():
		if c is CollisionPolygon2D:
			got.append((c as CollisionPolygon2D).polygon)
	assert_eq(got.size(), want, "one terrain polygon per kit polygon of every placed prop")
	for i in mini(got.size(), polys.size()):
		var a: PackedVector2Array = got[i]
		var b: PackedVector2Array = polys[i]
		assert_eq(a.size(), b.size())
		for k in a.size():
			assert_almost_eq(a[k].distance_to(b[k]), 0.0, 0.01)
	assert_false(m.get_node("Terrain").draw_shapes, "the art draws the terrain")


func test_us38_3_bedroom_is_a_valid_map_for_twelve() -> void:
	var m: GameMap = load("res://maps/bedroom/bedroom.tscn").instantiate()
	autofree(m)
	assert_gte(m.spawn_points().size(), 12, "spawn points for 12 players")
	assert_eq(m.team_bases().size(), 2, "team bases")
	var heights := {}
	for p in m.pickup_points():
		assert_gt(p.items.size(), 0, "%s lists items" % p.name)
		assert_true(m.bounds.has_point(p.position + Vector2(0, -1)), "%s inside bounds" % p.name)
		heights[int(-p.position.y / 200.0)] = true
	assert_gte(heights.size(), 4, "pickups spread across the heights")
	for s in m.spawn_points():
		assert_true(m.bounds.has_point(s.position + Vector2(0, -1)), "%s inside bounds" % s.name)


func test_bedroom_toys_spawn_standing_on_something() -> void:
	make([], Callable(), load("res://maps/bedroom/bedroom.tscn").instantiate())
	for i in sim.map.spawn_points().size():
		var t := sim.spawn_toy(i)
		for k in 30:
			sim.step({})
		assert_true(t.foot_contact, "spawn %s stands" % sim.map.spawn_points()[i].name)
		assert_lt(t.position.distance_to(sim.map.spawn_points()[i].position + Vector2(0, rules.body_bottom)), 6.0, "and stays put")


func test_the_game_plays_the_bedroom_by_default() -> void:
	var view := GameView.new()
	view.source = ScriptedSource.new(ScriptedInput.from_steps([{"t": 0.0, "move": [0, 0], "held": false}]))
	add_child_autofree(view)
	view.set_process(false)
	await wait_physics_frames(1)
	assert_eq(view.sim.map.name, &"Bedroom")
	assert_eq(view.map_scene.resource_path, "res://maps/bedroom/bedroom.tscn")


func test_every_svg_ships_as_kept_source() -> void:
	# The game rasters its own sheets; an SVG imported as a texture would cost a second copy.
	var dirs := ["res://assets"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d.path_join(sub))
		for f in DirAccess.get_files_at(d):
			if f.get_extension() == "svg":
				var imp := FileAccess.get_file_as_string(d.path_join(f) + ".import")
				assert_true(imp.contains("importer=\"keep\""), "%s is imported as keep" % d.path_join(f))
