class_name SeedPickup
extends Area2D
## Collectible seed. Replaces the demo's Coin (coin.gd emits on the Player,
## which couples the pickup to the player and HUD; this goes through GameState).
## Scene: Area2D (mask = layer 1 "player") > Sprite2D + CollisionShape2D.

@export var amount: int = 1
@export var bob_height: float = 3.0

var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var tween := create_tween().set_loops()
	tween.tween_property(self, ^"position:y", position.y - bob_height, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, ^"position:y", position.y, 0.6).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	_taken = true
	GameState.add_seeds(amount)
	EventBus.seed_collected.emit(amount, global_position)
	set_deferred(&"monitoring", false)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, ^"scale", Vector2(1.6, 1.6), 0.2)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(queue_free)
