extends Node
## Developer tool: measures frame times while walking through the world in a
## real window, first with everything on and then with single features turned
## off, to find what costs time. Prints a small table. Not part of the game.
##
## Run (needs a display, not --headless):
##   godot --path . res://tools/capture/perf_probe.tscn

const OVERWORLD := "res://game/scenes/world/overworld.tscn"
const WALK_SECONDS := 3.0

var world: Overworld


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://capture_tmp"))
	SessionState.progress = ProgressStore.new("user://capture_tmp/progress.cfg")
	SessionState.begin_session(5, AdaptiveComfortEngine.MODE_GENTLE, false)
	world = (load(OVERWORLD) as PackedScene).instantiate()
	add_child(world)
	await _wait(2.0)
	var rows: Array[String] = []
	var all_frames: PackedFloat32Array = []
	for spot: Array in [["grove", Vector2(2700, 1500), Vector2(1, 0.4)], ["creek", Vector2(6560, 3150), Vector2(0.3, 1)], ["pinewood", Vector2(1800, 3000), Vector2(1, 0.3)], ["coast", Vector2(6200, 4900), Vector2(1, 0)], ["village*", Vector2(5750, 3660), Vector2(-1, 0.2)]]:
		# The village is measured at night, with its lanterns on (0.4.0).
		TimeManager.load_state({"day": 3, "minute": (22.0 if String(spot[0]) == "village*" else 11.0) * 60.0})
		rows.append(await _measure("all on", spot, all_frames))
		_set_ground_detail(false)
		rows.append(await _measure("no 0.4.0 ground detail", spot))
		_set_ground_detail(true)
		world.features.atmosphere.visible = false
		rows.append(await _measure("no atmosphere layer", spot))
		world.features.atmosphere.visible = true
		world.features.wildlife.enabled = false
		world.features.wildlife.clear_all()
		rows.append(await _measure("no wildlife", spot))
		_set_m6_nodes(false)
		rows.append(await _measure("no M6 nodes at all", spot))
		_set_m6_nodes(true)
		world.features.wildlife.enabled = true
	print("\n".join(rows))
	all_frames.sort()
	var sum := 0.0
	for f in all_frames:
		sum += f
	print("ALL ON, every spot: average %.1f fps, 1%% low %.1f fps, worst frame %.1f ms (%.0f fps)" % [1000.0 / (sum / all_frames.size()), 1000.0 / all_frames[int(all_frames.size() * 0.99)], all_frames[-1], 1000.0 / all_frames[-1]])
	print("(village* = at night with the lanterns on)")
	print("objects loaded: %d, chunks: %d, vsync %d, fps cap %d" % [world.streamer.object_count(), world.streamer.loaded.size(), DisplayServer.window_get_vsync_mode(), Engine.max_fps])
	get_tree().quit()


func _measure(label: String, spot: Array, collect: PackedFloat32Array = PackedFloat32Array()) -> String:
	world.teleport_to(spot[1])
	await _wait(1.0)
	var frames: PackedFloat32Array = []
	var elapsed := 0.0
	var dir: Vector2 = (spot[2] as Vector2).normalized()
	while elapsed < WALK_SECONDS:
		world.player.velocity = dir * Player.SPEED * Player.RUN_MULTIPLIER
		world.player.move_and_slide()
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		frames.append(dt * 1000.0)
	collect.append_array(frames)
	frames.sort()
	var total := 0.0
	for f in frames:
		total += f
	var avg := total / frames.size()
	var p95 := frames[int(frames.size() * 0.95)]
	var cpu := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	return "%-9s %-22s avg %5.1f ms (%3.0f fps) p95 %5.1f worst %5.1f | process %4.1f ms physics %4.1f ms | draw calls %4d items %4d" % [spot[0], label, avg, 1000.0 / avg, p95, frames[-1], cpu, phys, calls, objs]


## Hides and stops every node added in M6 (to measure their total cost).
func _set_m6_nodes(on: bool) -> void:
	var fx := world.features
	fx.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	fx.atmosphere.visible = on
	var nodes: Array = fx.patches.values() + fx.gloomlings.values() + fx.docks.values() + fx.sites.values() + fx.kits + [fx.den, fx.wreck]
	for c in world.entities.get_children():
		if c is SceneryPiece:
			nodes.append(c)
	for n: Node2D in nodes:
		n.visible = on
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	for patch: GloomPatch in fx.patches.values():
		patch.veil.visible = on and patch.veil.strength > 0.005
		patch.mist.visible = on


## Hides the 0.4.0 ground detail (to measure its cost).
func _set_ground_detail(on: bool) -> void:
	for chunk_node: Node in world.streamer.loaded.values():
		for c in chunk_node.get_children(true):
			if c is GroundDetail:
				(c as GroundDetail).visible = on


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
