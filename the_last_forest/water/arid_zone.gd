class_name AridZone
extends Area2D
## Dry, cracked ground (Stage 3). Absorbs WaterDrop bodies from a directed
## stream. PlantingZones linked to it can't grow their saplings past SPROUT
## until it is hydrated — water management gates reforestation.
##
## Scene (arid_zone.tscn):
##   AridZone (Area2D, this script)  layer none, mask 8 "water"
##   ├─ CollisionShape2D   (wide rectangle covering the dry patch)
##   ├─ Ground (Polygon2D/Sprite2D)  cracked-earth art (assign to `visual`)
##   └─ Meter (ProgressBar, optional)  drops absorbed / needed

@export var drops_needed: int = 30
@export var visual: CanvasItem
@export var dry_color: Color = Color(0.85, 0.68, 0.45)
@export var wet_color: Color = Color(0.45, 0.65, 0.35)

var _absorbed: int = 0

@onready var _meter: Range = get_node_or_null(^"Meter") as Range


func _ready() -> void:
	collision_layer = 0
	collision_mask = WaterDrop.LAYER
	monitoring = true
	add_to_group(&"arid_zones")
	body_entered.connect(_on_body_entered)
	_update_visual()


func is_hydrated() -> bool:
	return _absorbed >= drops_needed


func hydration_ratio() -> float:
	return clampf(float(_absorbed) / float(maxi(1, drops_needed)), 0.0, 1.0)


func _on_body_entered(body: Node2D) -> void:
	if not body is WaterDrop:
		return
	(body as WaterDrop).absorb.call_deferred()
	if is_hydrated():
		return
	_absorbed += 1
	EventBus.water_delivered.emit(self, 1)
	_update_visual()
	if is_hydrated():
		EventBus.arid_zone_hydrated.emit(self)


func _update_visual() -> void:
	if visual != null:
		visual.modulate = dry_color.lerp(wet_color, hydration_ratio())
	if _meter != null:
		_meter.max_value = drops_needed
		_meter.value = _absorbed
