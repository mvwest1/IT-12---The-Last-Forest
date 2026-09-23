class_name AridZone
extends Interactable
## Dry, cracked ground (Stage 3). Needs `water_needed` drops poured on it
## (hold E, one drop per hold). PlantingZones linked to it can't grow their
## saplings past SPROUT until it is hydrated — this makes the water cycle
## a gate for reforestation, not a side quest.
##
## Scene (arid_zone.tscn):
##   AridZone (Area2D, this script)
##   ├─ CollisionShape2D   (wide rectangle covering the dry patch)
##   ├─ Ground (Sprite2D / NinePatchRect)  cracked-earth art (assign to `visual`)
##   ├─ Meter (TextureProgressBar, optional)  shows water poured
##   └─ Prompt (Label)  ("Hold E to water")

@export var water_needed: int = 3
@export var visual: CanvasItem
@export var dry_color: Color = Color(0.85, 0.68, 0.45)
@export var wet_color: Color = Color(1, 1, 1)

var _water: int = 0

@onready var _meter: Range = get_node_or_null(^"Meter") as Range


func _ready() -> void:
	super()
	hold_time = 0.6
	prompt_key = "PROMPT_WATER"
	add_to_group(&"arid_zones")
	_update_visual()


func is_hydrated() -> bool:
	return _water >= water_needed


func is_interactable() -> bool:
	return not is_hydrated()


func get_block_reason(_interactor: Node) -> StringName:
	if GameState.water_carried <= 0:
		return &"no_water"
	return &""


func complete_interaction(_interactor: Node) -> void:
	if is_hydrated() or not GameState.try_spend_water():
		return
	_water += 1
	EventBus.water_delivered.emit(self, 1)
	_update_visual()
	if is_hydrated():
		set_highlighted(false)
		EventBus.arid_zone_hydrated.emit(self)


func _update_visual() -> void:
	var t: float = float(_water) / float(maxi(1, water_needed))
	if visual != null:
		create_tween().tween_property(visual, ^"modulate", dry_color.lerp(wet_color, t), 0.4)
	if _meter != null:
		_meter.max_value = water_needed
		_meter.value = _water
