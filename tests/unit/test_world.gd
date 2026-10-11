extends "res://tests/test_case.gd"
## Tests for the V2 world foundation: authored data, deterministic chunk
## generation, placement rules, world state (fog, deltas, waystones).

const SCREEN := Vector2(1280, 720)

var _world: WorldData


func _w() -> WorldData:
	if _world == null:
		_world = WorldData.load_from()
	return _world


func test_world_data_loads_and_is_large_enough() -> void:
	var w := _w()
	assert_true(w.is_valid(), "world data valid: %s" % w.load_error)
	assert_eq(w.width_cells, 40)
	assert_eq(w.height_cells, 24)
	var screens := w.world_size() / SCREEN
	assert_true(screens.x >= 8.0 and screens.y >= 8.0, "at least 8x8 screens (got %s)" % str(screens))


func test_every_map_character_has_a_legend_entry() -> void:
	var w := _w()
	for row in w.rows:
		for i in row.length():
			assert_true(w.legend.has(row[i]), "legend for '%s'" % row[i])


func test_world_edges_are_natural_boundaries() -> void:
	var w := _w()
	for x in w.width_cells:
		assert_true(w.is_blocked_at(Vector2(x + 0.5, 0.5) * w.cell_size), "top edge blocked at %d" % x)
		assert_true(w.is_blocked_at(Vector2(x + 0.5, w.height_cells - 0.5) * w.cell_size), "bottom edge blocked at %d" % x)
	for y in w.height_cells:
		assert_true(w.is_blocked_at(Vector2(0.5, y + 0.5) * w.cell_size), "left edge blocked at %d" % y)
		assert_true(w.is_blocked_at(Vector2(w.width_cells - 0.5, y + 0.5) * w.cell_size), "right edge blocked at %d" % y)


func test_spawn_and_interactive_pois_are_on_walkable_ground() -> void:
	var w := _w()
	assert_false(w.is_blocked_at(w.player_spawn), "spawn walkable")
	assert_eq(w.region_at(w.player_spawn), "whispering_meadow")
	for p in w.pois:
		if bool(p.get("decorative", false)):
			continue
		assert_false(w.is_blocked_at(p["pos"]), "%s on walkable ground" % p["id"])
		assert_false(w.distance_to_river(p["pos"]) < 0.0, "%s not in the river" % p["id"])


func test_paths_run_over_walkable_ground() -> void:
	var w := _w()
	for path in w.paths:
		var pts: PackedVector2Array = path["points"]
		for i in range(pts.size() - 1):
			for k in 11:
				var p := pts[i].lerp(pts[i + 1], k / 10.0)
				assert_false(w.is_blocked_at(p), "path %s walkable at %s" % [path["id"], str(p)])


func test_chunk_generation_is_deterministic() -> void:
	var w := _w()
	var zones := [[w.player_spawn, 200.0]]
	var noise_a := ChunkGenerator.make_noise(w.world_seed)
	var noise_b := ChunkGenerator.make_noise(w.world_seed)
	for chunk in [Vector2i(4, 2), Vector2i(1, 1), Vector2i(6, 3)]:
		var a := ChunkGenerator.generate(w, chunk, zones, noise_a)
		var b := ChunkGenerator.generate(w, chunk, zones, noise_b)
		assert_eq(a.size(), b.size(), "same count for %s" % str(chunk))
		assert_true(a == b, "identical placements for %s" % str(chunk))
	var c1 := ChunkGenerator.generate(w, Vector2i(1, 1), zones, noise_a)
	var c2 := ChunkGenerator.generate(w, Vector2i(2, 1), zones, noise_a)
	assert_false(c1 == c2, "different chunks differ")


func test_placements_respect_paths_water_and_clearings() -> void:
	var w := _w()
	var noise := ChunkGenerator.make_noise(w.world_seed)
	var zones: Array = []
	for p in w.pois:
		zones.append([p["pos"], float(p["clear"])])
	var total := 0
	var n := w.chunk_count()
	for cy in n.y:
		for cx in n.x:
			for item in ChunkGenerator.generate(w, Vector2i(cx, cy), zones, noise):
				total += 1
				var pos: Vector2 = item["pos"]
				var kind := String(item["kind"])
				var is_gather := kind.begins_with(ChunkGenerator.GATHER_PREFIX)
				var margin := ChunkGenerator.GATHER_MARGIN if is_gather else float(ChunkGenerator.KINDS[kind]["margin"])
				if kind != "cliff_boulder":
					assert_false(w.is_blocked_at(pos), "%s not on blocked ground" % kind)
				assert_true(w.distance_to_paths(pos) >= margin, "%s keeps off paths" % kind)
				assert_true(w.distance_to_river(pos) >= 0.0, "%s not in the river" % kind)
				for z: Array in zones:
					assert_true(pos.distance_to(z[0]) >= float(z[1]), "%s outside clearings" % kind)
				if is_gather:
					assert_true(ItemDB.exists(kind.substr(ChunkGenerator.GATHER_PREFIX.length())), "%s is a real item" % kind)
				assert_true(w.chunk_rect(Vector2i(cx, cy)).grow(SCREEN.x).has_point(pos), "placement near its chunk")
	# Sanity floor only (about 48 objects per chunk incl. sea chunks); density is judged visually.
	assert_true(total > 2000, "the world is filled with scenery (%d objects)" % total)


func test_chunk_math() -> void:
	var w := _w()
	assert_eq(w.chunk_size(), 1024.0)
	assert_eq(w.chunk_count(), Vector2i(10, 6))
	assert_eq(w.chunk_of(Vector2(1500, 3000)), Vector2i(1, 2))
	assert_true(w.chunk_rect(Vector2i(1, 2)).has_point(Vector2(1500, 3000)))
	assert_false(w.is_chunk_inside(Vector2i(-1, 0)))
	assert_false(w.is_chunk_inside(Vector2i(10, 0)))


func test_game_state_fog_deltas_and_waystones() -> void:
	var gs: Node = load("res://game/scripts/autoload/game_state.gd").new()
	gs.call("reset_world", Vector2(10240, 6144))
	assert_false(gs.call("is_revealed", Vector2(500, 500)))
	assert_true(gs.call("reveal", Vector2(500, 500), 300.0), "reveal changes fog")
	assert_true(gs.call("is_revealed", Vector2(500, 500)))
	assert_false(gs.call("reveal", Vector2(500, 500), 300.0), "revealing again changes nothing")
	assert_false(gs.call("is_revealed", Vector2(5000, 5000)))
	gs.call("mark_removed", Vector2i(2, 3), "2_3_7")
	assert_true(gs.call("is_removed", Vector2i(2, 3), "2_3_7"))
	assert_false(gs.call("is_removed", Vector2i(2, 3), "2_3_8"))
	assert_true(gs.call("set_waystone_state", "ws_a", "discovered"))
	assert_true(gs.call("set_waystone_state", "ws_a", "restored"))
	assert_false(gs.call("set_waystone_state", "ws_a", "discovered"), "waystones never go backwards")
	assert_eq((gs.call("restored_waystones") as PackedStringArray).size(), 1)
	assert_true(gs.call("mark_region_visited", "firefly_grove"))
	assert_false(gs.call("mark_region_visited", "firefly_grove"), "first visit only once")
	gs.call("add_pin", Vector2(100, 100))
	assert_true(gs.call("remove_pin_near", Vector2(110, 105), 40.0))
	assert_false(gs.call("remove_pin_near", Vector2(110, 105), 40.0))
	gs.free()
