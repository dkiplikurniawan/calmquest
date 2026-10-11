class_name Footsteps
extends RefCounted
## Which footstep sound fits the ground under the player: grass, path (dirt),
## wood (the cottage, bridges and docks), sand (the coast and isles), snow (the
## highlands) or stone (caves). Read from the world data and the sub-level.
## Settings > Audio > Footsteps turns them off.

const SAND_REGIONS: PackedStringArray = ["sunpetal_coast", "sunpetal_isles"]
const SNOW_REGIONS: PackedStringArray = ["frostbloom_highlands"]
## How close to a dock the ground counts as its planks.
const DOCK_RADIUS := 110.0


static func surface_for(region: String, sublevel: String, on_path: bool, on_wood: bool) -> String:
	if sublevel == "cottage":
		return "wood"
	if sublevel.begins_with("cave"):
		return "stone"
	if on_wood:
		return "wood"
	if SNOW_REGIONS.has(region):
		return "snow"
	if SAND_REGIONS.has(region):
		return "sand"
	if on_path:
		return "path"
	return "grass"


static func surface_at(world: WorldData, pos: Vector2, sublevel: String) -> String:
	if not sublevel.is_empty():
		return surface_for("", sublevel, false, false)
	var on_wood := world.is_on_crossing(pos)
	if not on_wood:
		for dock in world.pois_of_kind("dock"):
			if pos.distance_to(dock["pos"]) < DOCK_RADIUS:
				on_wood = true
				break
	return surface_for(world.region_at(pos), sublevel, world.distance_to_paths(pos) < 0.0, on_wood)
