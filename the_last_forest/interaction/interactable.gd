class_name Interactable
extends Area2D
## Base class for everything the player "holds E" on: PlantingZone, Sapling
## (revive), AridZone (water). One verb for every mechanic keeps the controls
## learnable for young players.
##
## Subclasses that override _ready() MUST call super().
## Optional child node named "Prompt" (e.g. a Label "Hold E") is shown
## automatically when this is the player's current target.

## Physics layer 6 — name it "interactables" in Project Settings.
const LAYER: int = 1 << 5

@export var hold_time: float = 1.0
@export var prompt_key: String = "PROMPT_HOLD_E"

@onready var _prompt: CanvasItem = get_node_or_null(^"Prompt") as CanvasItem


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	if _prompt != null:
		_prompt.hide()
		if _prompt is Label:
			(_prompt as Label).text = tr(prompt_key)


## Can the player target this right now? (Controls whether the prompt shows.)
func is_interactable() -> bool:
	return true


## Return &"" to allow, or a reason key (&"no_seeds", &"occupied", ...).
func get_block_reason(_interactor: Node) -> StringName:
	return &""


func set_highlighted(on: bool) -> void:
	if _prompt != null:
		_prompt.visible = on


func on_interaction_started(_interactor: Node) -> void:
	pass


func on_interaction_cancelled(_interactor: Node) -> void:
	pass


func complete_interaction(_interactor: Node) -> void:
	pass
