extends "res://tests/test_case.gd"
## Tests for the 0.4.0 visual pass (P4): ground detail and small features are
## deterministic and stay out of the way, character sprite sheets fall back to
## the procedural art when absent, the Traveler blinks and puffs (respecting
## Reduce motion), Lumi celebrates, and the finale's cinematic layer can be
## skipped exactly once.

var _world: WorldData


func _w() -> WorldData:
	if _world == null:
		_world = WorldData.load_from()
	return _world


func _root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


func _zones(w: WorldData) -> Array:
	var zones: Array = []
	for p in w.pois:
		zones.append([p["pos"], float(p["clear"])])
	return zones


func test_features_are_deterministic_and_keep_off_paths() -> void:
	var w := _w()
	var zones := _zones(w)
	var noise_a := ChunkGenerator.make_noise(w.world_seed)
	var noise_b := ChunkGenerator.make_noise(w.world_seed)
	var n := w.chunk_count()
	var total := 0
	var kinds := {}
	for cy in n.y:
		for cx in n.x:
			var chunk := Vector2i(cx, cy)
			var objects := ChunkGenerator.generate(w, chunk, zones, noise_a)
			var a := ChunkGenerator.generate_features(w, chunk, zones, noise_a, objects)
			var b := ChunkGenerator.generate_features(w, chunk, zones, noise_b, ChunkGenerator.generate(w, chunk, zones, noise_b))
			assert_true(a == b, "features are identical for %s" % str(chunk))
			assert_true(a.size() <= 1, "at most one feature per chunk")
			for f in a:
				total += 1
				var pos: Vector2 = f["pos"]
				kinds[String(f["kind"])] = true
				assert_eq(String(f["id"]), "f_%d_%d" % [cx, cy], "feature ids never clash with scenery ids")
				assert_false(w.is_blocked_at(pos), "%s stands on open ground" % f["kind"])
				assert_true(w.distance_to_paths(pos) >= ChunkGenerator.FEATURE_PATH_MARGIN, "%s keeps off paths" % f["kind"])
				assert_true(w.distance_to_river(pos) >= ChunkGenerator.FEATURE_PATH_MARGIN, "%s keeps off the river" % f["kind"])
				for z: Array in zones:
					assert_true(pos.distance_to(z[0]) >= float(z[1]), "%s stays outside clearings" % f["kind"])
				for o in objects:
					assert_true(pos.distance_to(o["pos"]) >= ChunkGenerator.FEATURE_OBJECT_GAP, "%s keeps a gap to other scenery" % f["kind"])
	assert_true(total > 10, "features appear across the world (%d)" % total)
	assert_true(kinds.size() >= 3, "several kinds of features appear (%s)" % str(kinds.keys()))


func test_features_never_block_movement() -> void:
	for kind_name in ChunkGenerator.FEATURES:
		var d := Decoration.new()
		d.kind = Decoration.kind_from_name(kind_name)
		d._add_collision()
		assert_eq(d.get_child_count(), 0, "%s has no collision" % kind_name)
		d.free()


func test_feature_stream_leaves_regular_scenery_unchanged() -> void:
	var w := _w()
	var zones := _zones(w)
	var noise := ChunkGenerator.make_noise(w.world_seed)
	var chunk := Vector2i(4, 2)
	var before := ChunkGenerator.generate(w, chunk, zones, noise)
	ChunkGenerator.generate_features(w, chunk, zones, noise, before)
	var after := ChunkGenerator.generate(w, chunk, zones, noise)
	assert_true(before == after, "the regular scenery (and its ids) is unchanged")


func test_ground_detail_is_deterministic_and_has_no_collision() -> void:
	var w := _w()
	var noise := ChunkGenerator.make_noise(w.world_seed)
	for chunk in [Vector2i(4, 2), Vector2i(2, 4), Vector2i(7, 3)]:
		var objects := ChunkGenerator.generate(w, chunk, _zones(w), noise)
		var a := GroundDetail.new()
		var b := GroundDetail.new()
		a.setup(w, chunk, objects)
		b.setup(w, chunk, objects)
		assert_true(a.tufts == b.tufts and a.flowers == b.flowers and a.leaves == b.leaves and a.pebbles == b.pebbles, "ground detail is identical for %s" % str(chunk))
		assert_true(a.tufts.size() + a.flowers.size() + a.pebbles.size() > 0, "%s has some ground detail" % str(chunk))
		for t: Array in a.tufts:
			assert_false(w.is_blocked_at(t[0]), "tufts sit on open ground")
		assert_eq(a.get_child_count(), 0, "ground detail adds no collision")
		assert_eq(a.z_index, GroundDetail.Z, "ground detail is drawn under everything")
		a.free()
		b.free()


func test_character_sprites_fall_back_to_procedural_art() -> void:
	CharacterSprites.clear_cache()
	assert_false(ResourceLoader.exists(CharacterSprites.TRAVELER_PATH), "no Traveler sheet is shipped yet (honest default)")
	assert_null(CharacterSprites.traveler(), "without the sheet the Traveler is drawn in code")
	assert_null(CharacterSprites.lumi(), "without the sheet Lumi is drawn in code")
	# A file that is too small for the expected frames is ignored (with a warning).
	assert_null(CharacterSprites.sheet("res://icon.svg", CharacterSprites.TRAVELER_FRAME, CharacterSprites.TRAVELER_COLUMNS, CharacterSprites.TRAVELER_ROWS), "a sheet that is too small is not used")
	CharacterSprites.clear_cache()
	assert_eq(CharacterSprites.traveler_row(Vector2.DOWN), 0)
	assert_eq(CharacterSprites.traveler_row(Vector2.UP), 1)
	assert_eq(CharacterSprites.traveler_row(Vector2.LEFT), 2)
	assert_eq(CharacterSprites.traveler_row(Vector2(0.9, 0.3)), 3, "mostly right means the right-facing row")
	assert_eq(CharacterSprites.traveler_column(1.0, false, false), 4, "idle frame")
	assert_eq(CharacterSprites.traveler_column(1.0, false, true), 5, "blink frame")
	for i in 20:
		var c := CharacterSprites.traveler_column(i * 0.13, true, false)
		assert_true(c >= 0 and c <= 3, "walk frames are columns 0-3")


func test_traveler_blinks_and_puffs_with_reduce_motion_respected() -> void:
	var old_reduce := GameSettings.reduce_motion
	GameSettings.reduce_motion = false
	var p := Player.new()
	_root().add_child(p)
	p._t = 10.0
	p._blink_at = 10.0
	assert_true(p.is_blinking(), "the Traveler blinks now and then")
	p._t = 10.0 + Player.BLINK_SECONDS + 0.05
	assert_false(p.is_blinking(), "a blink is short")
	p.velocity = Vector2(300, 0)
	p.running = true
	p._process(0.016)
	assert_true(p.puff_count() > 0, "a little puff appears when starting to run")
	p._process(Player.PUFF_SECONDS + 0.05)
	assert_eq(p.puff_count(), 0, "the puff fades, and running on does not repeat it")
	p.free()
	GameSettings.reduce_motion = true
	var q := Player.new()
	_root().add_child(q)
	q.velocity = Vector2(300, 0)
	q.running = true
	q._process(0.016)
	assert_eq(q.puff_count(), 0, "no puffs with Reduce motion")
	q.free()
	GameSettings.reduce_motion = old_reduce


func test_lumi_celebrates_for_a_while() -> void:
	var lumi := Lumi.new()
	_root().add_child(lumi)
	assert_false(lumi.is_celebrating())
	lumi.celebrate(1.0)
	assert_true(lumi.is_celebrating(), "Lumi celebrates the finale")
	lumi._process(0.5)
	assert_true(lumi.is_celebrating(), "for a while")
	lumi._process(0.6)
	assert_false(lumi.is_celebrating(), "and then floats calmly again")
	lumi.free()


func test_finale_cinematic_can_be_skipped_once() -> void:
	var layer := FinaleCinematic.new()
	_root().add_child(layer)
	var skips := [0]
	layer.skip_requested.connect(func() -> void: skips[0] += 1)
	assert_eq(layer.hold_progress(), 0.0, "nothing is held at first")
	assert_false(layer.skipped)
	layer.request_skip()
	layer.request_skip()
	assert_true(layer.skipped, "the finale can be skipped")
	assert_eq(skips[0], 1, "skipping happens once")
	layer.roll_credits(PackedStringArray(["Built with the Godot Engine (MIT license)."]), 5.0)
	assert_true(layer.credits_text().contains("Godot"), "the credits list the lines given")
	assert_true(layer.credits_text().contains("Thank you for playing."), "and end with a thank-you")
	layer.start_motes()
	assert_true(layer.motes_active(), "motes of light rise")
	layer.free()
