class_name WaterDrop
extends Area2D
## Collectible water drop (Stage 3). Player carries up to
## GameState.water_capacity drops and pours them on AridZones (hold E).
## If the player's can is full, the drop stays put and a tip explains why.
## Optional: set fall_speed > 0 to make it drip from a cloud/leaf until it
## lands on a ground ray (simple "rain" feel).

@export var amount: int = 1
@export var fall_speed: float = 0.0

var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if fall_speed > 0.0 and not _taken:
		position.y += fall_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	if not GameState.add_water(amount):
		EventBus.tip_requested.emit("TIP_WATER_FULL")
		return
	_taken = true
	set_deferred(&"monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
