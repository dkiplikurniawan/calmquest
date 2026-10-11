class_name QuestFacts
extends RefCounted
## Answers QuestBook conditions from the live game state.
##
## Every fact comes from GameState (persistent world state), so quest progress
## survives saving and loading.

func has_flag(key: String) -> bool:
	return GameState.has_flag(key)


## Counters live in GameState ("lights_collected", "lantern_nights",
## "obtained:<item>", "crafted:<item>", ...), so progress persists with the world.
func counter(key: String) -> int:
	return GameState.counter(key)


func region_visited(region_id: String) -> bool:
	return GameState.has_visited(region_id)


func waystone_restored(waystone_id: String) -> bool:
	return GameState.waystone_state(waystone_id) == GameState.WAYSTONE_RESTORED
