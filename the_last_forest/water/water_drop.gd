class_name WaterDrop
extends RigidBody2D
## One droplet in a WaterSource stream. Rolls along ground and Diverter ramps.
## Absorbed by an AridZone, or evaporates after `lifetime` seconds.
##
## Scene (water_drop.tscn):
##   WaterDrop (RigidBody2D, this script)
##     collision_layer = layer 8 "water"
##     collision_mask  = layers 4 "platforms" + 5 "ground" (24)
##     (NOT the player — water never blocks or pushes the child)
##   ├─ Sprite2D (small blue drop)
##   └─ CollisionShape2D (circle r≈4)

const LAYER: int = 1 << 7   # physics layer 8 "water"

@export var lifetime: float = 7.0


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = (1 << 3) | (1 << 4) | (1 << 8)  # platforms, ground, water_guides
	add_to_group(&"water_drops")
	var tween := create_tween()
	tween.tween_interval(maxf(lifetime - 0.5, 0.0))
	tween.tween_property(self, ^"modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)


func absorb() -> void:
	remove_from_group(&"water_drops")
	queue_free()
