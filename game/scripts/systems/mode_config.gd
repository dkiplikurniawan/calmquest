class_name ModeConfig
extends Resource
## Data container describing one gameplay mode (Gentle, Balanced, Playful).
## Gameplay nodes read these values; they never hard-code per-mode numbers.

@export var mode_id: StringName = &"balanced"
@export var display_name: String = "Balanced"
@export_multiline var description: String = ""

## Multiplier for how much collectibles bob and drift (0 = still).
@export var collectible_activity: float = 1.0
## Distance in pixels within which the player can interact with an object.
@export var interaction_radius: float = 72.0
## Show soft markers on interactable objects near the player (more visible prompts).
@export var show_nearby_markers: bool = false
## Whether the guiding arrow towards the nearest light starts enabled.
@export var guidance_arrow_default: bool = false
## Number of optional bonus objects (Prism Motes) shown in the meadow.
@export var bonus_object_count: int = 0
## Scales decorative motion (bobbing, swaying). Reduce Motion further scales this.
@export var animation_intensity: float = 1.0

## Lantern Catch: lanterns required to fill the night sky.
@export var lantern_count: int = 8
## Lantern Catch: extra optional golden lanterns.
@export var bonus_lantern_count: int = 0
## Lantern Catch: drift speed in pixels per second.
@export var lantern_drift_speed: float = 18.0
## Lantern Catch: how far a lantern may wander from its anchor point.
@export var lantern_wander_radius: float = 60.0


func duplicate_config() -> ModeConfig:
	return duplicate(true) as ModeConfig


func to_dictionary() -> Dictionary:
	return {
		"mode_id": String(mode_id),
		"display_name": display_name,
		"collectible_activity": collectible_activity,
		"interaction_radius": interaction_radius,
		"show_nearby_markers": show_nearby_markers,
		"guidance_arrow_default": guidance_arrow_default,
		"bonus_object_count": bonus_object_count,
		"animation_intensity": animation_intensity,
		"lantern_count": lantern_count,
		"bonus_lantern_count": bonus_lantern_count,
		"lantern_drift_speed": lantern_drift_speed,
		"lantern_wander_radius": lantern_wander_radius,
	}
