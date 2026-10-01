class_name WaterSource
extends Node2D
## Stage 3: a spring / broken pipe that emits a steady stream of WaterDrop
## bodies. The player can't carry water — they DIRECT the stream with
## Diverter levers so it reaches the AridZone (water management, not fetching).

@export var drop_scene: PackedScene
@export var interval: float = 0.25
@export var initial_velocity: Vector2 = Vector2(0, 40)
## Hard cap keeps low-spec lab PCs smooth.
@export var max_alive: int = 40

var _timer: float = 0.0


func _physics_process(delta: float) -> void:
	if drop_scene == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval
	if get_tree().get_nodes_in_group(&"water_drops").size() >= max_alive:
		return
	var drop := drop_scene.instantiate() as RigidBody2D
	drop.position = position + Vector2(randf_range(-3.0, 3.0), 0.0)
	drop.linear_velocity = initial_velocity
	get_parent().add_child(drop)
