class_name WorldStreamer
extends Node
## Streams scenery chunks around the camera.
##
## * Needed chunks = chunks touching the camera view grown by LOAD_MARGIN, so a
##   chunk is built before it can appear on screen (no visible pop-in).
## * Chunks farther than UNLOAD_MARGIN from the view are freed.
## * At most MAX_BUILDS_PER_FRAME chunks are built per frame (no frame spikes);
##   teleports call load_rect_now() to build synchronously behind a fade.
## * Objects removed by gameplay are recorded in GameState and skipped on rebuild.

signal chunk_loaded(chunk: Vector2i)
signal chunk_unloaded(chunk: Vector2i)
signal gatherable_interacted(gatherable: Gatherable)

const DECORATION_SCENE := preload("res://game/scenes/world/decoration.tscn")
const LOAD_MARGIN := 640.0
const UNLOAD_MARGIN := 1600.0
const MAX_BUILDS_PER_FRAME := 1
const OBJECT_ID_META := &"object_id"

var world: WorldData
var parent_node: Node2D
var clear_zones: Array = []
var sway_intensity: float = 1.0
var loaded: Dictionary = {}
## Build timings in microseconds (for the performance report).
var last_build_usec: int = 0
var max_build_usec: int = 0
var total_builds: int = 0

var _noise: FastNoiseLite
var _queue: Array[Vector2i] = []
var _view_center: Vector2 = Vector2.ZERO


func setup(world_data: WorldData, entities: Node2D, zones: Array) -> void:
	world = world_data
	parent_node = entities
	clear_zones = zones
	_noise = ChunkGenerator.make_noise(world.world_seed)


## Call regularly with the camera's visible world rectangle.
func update_view(view_rect: Rect2) -> void:
	_view_center = view_rect.get_center()
	for chunk in chunks_in(view_rect.grow(LOAD_MARGIN)):
		if not loaded.has(chunk) and not _queue.has(chunk):
			_queue.append(chunk)
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return world.chunk_rect(a).get_center().distance_squared_to(_view_center) < world.chunk_rect(b).get_center().distance_squared_to(_view_center))
	var keep := view_rect.grow(UNLOAD_MARGIN)
	for chunk: Vector2i in loaded.keys():
		if not world.chunk_rect(chunk).intersects(keep):
			unload_chunk(chunk)
	for chunk in _queue.duplicate():
		if not world.chunk_rect(chunk).intersects(keep):
			_queue.erase(chunk)


func _process(_delta: float) -> void:
	var built := 0
	while built < MAX_BUILDS_PER_FRAME and not _queue.is_empty():
		var chunk: Vector2i = _queue.pop_front()
		if not loaded.has(chunk):
			build_chunk(chunk)
			built += 1


func chunks_in(rect: Rect2) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size := world.chunk_size()
	var from := Vector2i(floori(rect.position.x / size), floori(rect.position.y / size))
	var to := Vector2i(floori(rect.end.x / size), floori(rect.end.y / size))
	for y in range(from.y, to.y + 1):
		for x in range(from.x, to.x + 1):
			var c := Vector2i(x, y)
			if world.is_chunk_inside(c):
				result.append(c)
	return result


## Builds every chunk touching `rect` immediately (used behind fades and in tests).
func load_rect_now(rect: Rect2) -> void:
	for chunk in chunks_in(rect):
		if not loaded.has(chunk):
			build_chunk(chunk)
		_queue.erase(chunk)


func load_all() -> void:
	load_rect_now(world.world_rect())


func build_chunk(chunk: Vector2i) -> Node2D:
	var start := Time.get_ticks_usec()
	var node := Node2D.new()
	node.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	node.y_sort_enabled = true
	var objects := ChunkGenerator.generate(world, chunk, clear_zones, _noise)
	var ground := GroundDetail.new()
	ground.setup(world, chunk, objects)
	# Internal child: the chunk's own children stay exactly its world objects.
	node.add_child(ground, false, Node.INTERNAL_MODE_FRONT)
	objects.append_array(ChunkGenerator.generate_features(world, chunk, clear_zones, _noise, objects))
	for p: Dictionary in objects:
		if GameState.is_removed(chunk, String(p["id"])):
			continue
		var kind_name := String(p["kind"])
		if kind_name.begins_with(ChunkGenerator.GATHER_PREFIX):
			var g := Gatherable.new()
			g.item_id = kind_name.substr(ChunkGenerator.GATHER_PREFIX.length())
			g.interactable_id = "res_" + String(p["id"])
			g.chunk = chunk
			g.respawn_days = int(p.get("respawn", 2))
			g.position = p["pos"]
			g.scale = Vector2.ONE * float(p["size"])
			g.set_meta(OBJECT_ID_META, p["id"])
			g.interacted.connect(func(t: Interactable) -> void: gatherable_interacted.emit(t as Gatherable))
			node.add_child(g)
			continue
		var d: Decoration = DECORATION_SCENE.instantiate()
		d.kind = Decoration.kind_from_name(String(p["kind"]))
		d.size = float(p["size"])
		d.variant = int(p["variant"])
		d.position = p["pos"]
		d.sway_intensity = sway_intensity
		d.set_meta(OBJECT_ID_META, p["id"])
		node.add_child(d)
	parent_node.add_child(node)
	loaded[chunk] = node
	last_build_usec = Time.get_ticks_usec() - start
	max_build_usec = maxi(max_build_usec, last_build_usec)
	total_builds += 1
	chunk_loaded.emit(chunk)
	return node


func unload_chunk(chunk: Vector2i) -> void:
	var node: Node2D = loaded.get(chunk)
	if node != null:
		node.queue_free()
	loaded.erase(chunk)
	chunk_unloaded.emit(chunk)


## Removes one generated object and remembers it, so it stays gone after
## reloads (respawn_days > 0: it grows back after that many in-game days).
func remove_object(chunk: Vector2i, object_id: String, respawn_days: int = 0) -> bool:
	GameState.mark_removed(chunk, object_id, respawn_days)
	var node: Node2D = loaded.get(chunk)
	if node == null:
		return false
	for child in node.get_children():
		if child.get_meta(OBJECT_ID_META, "") == object_id:
			if child is Gatherable:
				(child as Gatherable).play_gathered()
			else:
				child.queue_free()
			return true
	return false


func object_count() -> int:
	var n := 0
	for node: Node2D in loaded.values():
		n += node.get_child_count()
	return n


func set_sway_intensity(value: float) -> void:
	sway_intensity = value
	for node: Node2D in loaded.values():
		for d in node.get_children():
			if d is Decoration:
				(d as Decoration).sway_intensity = value
