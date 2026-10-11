extends Node
## Global gameplay events (autoload "EventBus").
## Systems emit facts here; listeners (quests, HUD, Lumi, audio) react without
## knowing about each other. Events never carry research/session data.

signal region_entered(region_id: String, first_visit: bool)
signal waystone_discovered(waystone_id: String)
signal waystone_restored(waystone_id: String)
signal player_traveled(waystone_id: String)
signal landmark_seen(landmark_id: String)
signal puzzle_solved(puzzle_id: String)
signal story_flag_set(flag: String)
signal quest_started(quest_id: String)
signal quest_step_completed(quest_id: String, step_index: int)
signal quest_completed(quest_id: String)
## Generic "something changed that quests may care about".
signal progress_changed
## A short HUD toast from systems that have no HUD reference (e.g. puzzles).
signal toast_requested(text: String)
