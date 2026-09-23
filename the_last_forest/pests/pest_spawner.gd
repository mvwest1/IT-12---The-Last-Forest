class_name PestSpawner
extends Node2D
## Spawns pests from child Marker2D points, but ONLY while at least one
## sapling is vulnerable. Once every tree has matured, the pressure stops —
## the player sees that protecting young trees is temporary but essential.

@export var pest_scene: PackedScene
@export var first_delay: float = 5.0
@export var spawn_interval: float = 7.0
@export var max_alive: int = 3

var _cooldown: float = 0.0


func _ready() -> void:
	_cooldown = first_delay


func _process(delta: float) -> void:
	if pest_scene == null or not _any_vulnerable():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	_cooldown = spawn_interval
	if get_tree().get_nodes_in_group(&"pests").size() >= max_alive:
		return
	var points: Array[Marker2D] = []
	for child: Node in get_children():
		if child is Marker2D:
			points.append(child as Marker2D)
	if points.is_empty():
		return
	var pest := pest_scene.instantiate() as Node2D
	get_parent().add_child(pest)
	pest.global_position = points.pick_random().global_position


func _any_vulnerable() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"saplings"):
		if (node as Sapling).is_vulnerable():
			return true
	return false
