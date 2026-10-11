class_name ChunkGenerator
extends RefCounted
## Deterministic, seeded placement of small scenery inside one chunk.
##
## The macro layout (biomes, paths, rivers, POIs) is authored in WorldData; this
## only fills in details. The same world seed and chunk always produce the same
## list, so the world is identical on every launch and testable.
## Rules: never on blocked or water cells (except decorative cliff boulders),
## never on paths or rivers, never inside a point-of-interest clearing.

## Distance between candidate points in pixels. Each candidate is jittered.
const SPACING := 72.0
const JITTER := 0.3
## Scale of the clustering noise (bigger = larger forests and clearings).
const CLUSTER_FREQUENCY := 0.0016

## margin: minimum free distance to paths/rivers/clearings.
## size: [min, max] scale. near_water: only placed close to a river bank.
const KINDS := {
	"tree": {"margin": 40.0, "size": [0.85, 1.15]},
	"grove_tree": {"margin": 40.0, "size": [0.9, 1.15]},
	"pine": {"margin": 36.0, "size": [0.9, 1.2]},
	"snow_pine": {"margin": 36.0, "size": [0.85, 1.15]},
	"bush": {"margin": 26.0, "size": [0.75, 1.1]},
	"flower": {"margin": 6.0, "size": [0.8, 1.2]},
	"grass": {"margin": 4.0, "size": [0.8, 1.3]},
	"stone": {"margin": 24.0, "size": [0.6, 1.1]},
	"boulder": {"margin": 40.0, "size": [0.9, 1.4]},
	"cliff_boulder": {"margin": 0.0, "size": [1.0, 1.8]},
	"mushroom": {"margin": 10.0, "size": [0.7, 1.1]},
	"glowcap": {"margin": 12.0, "size": [0.8, 1.3]},
	"fern": {"margin": 8.0, "size": [0.8, 1.2]},
	"reeds": {"margin": 6.0, "size": [0.8, 1.2], "near_water": true},
	"crystal": {"margin": 24.0, "size": [0.7, 1.2]},
	"moon_lily": {"margin": 6.0, "size": [0.8, 1.2]},
	"pillar": {"margin": 40.0, "size": [0.9, 1.1]},
	"beach_grass": {"margin": 4.0, "size": [0.8, 1.2]},
	"driftwood": {"margin": 14.0, "size": [0.8, 1.2]},
	"shell": {"margin": 4.0, "size": [0.7, 1.1]},
	"frost_flower": {"margin": 6.0, "size": [0.8, 1.2]},
}
const NEAR_WATER_MAX := 70.0
## Gatherable resources that only grow at the water's edge.
const WATERSIDE_ITEMS := ["reed", "clay"]
const GATHER_MARGIN := 12.0
const GATHER_PREFIX := "gather:"


## Returns an Array of {id, kind, pos, size, variant} for `chunk`. Gatherable
## resources have kind "gather:<item_id>" and an extra "respawn" (days).
## clear_zones: Array of [Vector2 center, float radius] kept free (POIs, objects).
static func generate(world: WorldData, chunk: Vector2i, clear_zones: Array, noise: FastNoiseLite) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not world.is_chunk_inside(chunk):
		return result
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, chunk.x, chunk.y])
	var rect := world.chunk_rect(chunk)
	var zones := _zones_near(clear_zones, rect.grow(200.0))
	var steps := int(world.chunk_size() / SPACING)
	var index := 0
	for gy in steps:
		for gx in steps:
			var jitter := Vector2(rng.randf_range(-JITTER, JITTER), rng.randf_range(-JITTER, JITTER))
			var pos := rect.position + (Vector2(gx, gy) + Vector2(0.5, 0.5) + jitter) * SPACING
			var roll := rng.randf()
			var size_roll := rng.randf()
			var variant := rng.randi_range(0, 999)
			var gather_roll := rng.randf()
			var kind := _pick_kind(world, pos, roll, noise)
			if kind.is_empty() or not _placement_allowed(world, kind, pos, zones):
				var gather := _pick_gather(world, pos, gather_roll, zones)
				if not gather.is_empty():
					result.append({
						"id": "%d_%d_%d" % [chunk.x, chunk.y, index],
						"kind": GATHER_PREFIX + String(gather[0]),
						"pos": pos,
						"size": lerpf(0.85, 1.15, size_roll),
						"variant": variant,
						"respawn": int(gather[2]),
					})
					index += 1
				continue
			var spec: Dictionary = KINDS[kind]
			var size_range: Array = spec["size"]
			result.append({
				"id": "%d_%d_%d" % [chunk.x, chunk.y, index],
				"kind": kind,
				"pos": pos,
				"size": lerpf(float(size_range[0]), float(size_range[1]), size_roll),
				"variant": variant,
			})
			index += 1
	return result


## Chooses a gatherable resource for this spot, or [] if none fits here.
static func _pick_gather(world: WorldData, pos: Vector2, roll: float, zones: Array) -> Array:
	var profile := world.gather_profile_at(pos)
	if profile.is_empty() or world.is_blocked_at(pos):
		return []
	var cumulative := 0.0
	for entry: Array in profile:
		cumulative += float(entry[1])
		if roll >= cumulative:
			continue
		if world.distance_to_paths(pos) < GATHER_MARGIN:
			return []
		var river_gap := world.distance_to_river(pos)
		if WATERSIDE_ITEMS.has(String(entry[0])):
			if river_gap < 4.0 or river_gap > NEAR_WATER_MAX * 1.6:
				return []
		elif river_gap < GATHER_MARGIN + 8.0:
			return []
		for z: Array in zones:
			if pos.distance_to(z[0]) < float(z[1]):
				return []
		return entry
	return []


static func make_noise(world_seed: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = world_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = CLUSTER_FREQUENCY
	return n


## Chooses a kind from the cell's decoration profile. Clustering noise makes
## forests denser in some places and opens clearings in others.
static func _pick_kind(world: WorldData, pos: Vector2, roll: float, noise: FastNoiseLite) -> String:
	var profile := world.decor_profile_at(pos)
	if profile.is_empty():
		return ""
	var cluster := 0.55 + 0.9 * (noise.get_noise_2dv(pos) * 0.5 + 0.5)
	var cumulative := 0.0
	for entry: Array in profile:
		var kind := String(entry[0])
		var chance := float(entry[1])
		if kind.ends_with("tree") or kind.ends_with("pine"):
			chance *= cluster
		cumulative += chance
		if roll < cumulative:
			if kind == "boulder" and world.is_blocked_at(pos):
				return "cliff_boulder"
			return kind
	return ""


static func _placement_allowed(world: WorldData, kind: String, pos: Vector2, zones: Array) -> bool:
	var spec: Dictionary = KINDS.get(kind, {})
	if spec.is_empty():
		return false
	if kind != "cliff_boulder" and world.is_blocked_at(pos):
		return false
	var margin := float(spec["margin"])
	if world.distance_to_paths(pos) < margin:
		return false
	var river_gap := world.distance_to_river(pos)
	if bool(spec.get("near_water", false)):
		if river_gap < 4.0 or river_gap > NEAR_WATER_MAX:
			return false
	elif river_gap < margin + 8.0:
		return false
	for z: Array in zones:
		if pos.distance_to(z[0]) < float(z[1]) + margin * 0.5:
			return false
	return true


static func _zones_near(zones: Array, rect: Rect2) -> Array:
	var near: Array = []
	for z: Array in zones:
		var c: Vector2 = z[0]
		var r := float(z[1])
		if rect.grow(r).has_point(c):
			near.append(z)
	return near
