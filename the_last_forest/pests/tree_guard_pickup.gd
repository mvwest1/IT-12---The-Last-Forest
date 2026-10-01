class_name TreeGuardPickup
extends Area2D
## Collectible Tree Guard (bamboo fence). Hold E on a young sapling to fence it.
## Scene: Area2D (mask = layer 1 "player") > Sprite2D + CollisionShape2D.

@export var amount: int = 1

var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	_taken = true
	GameState.add_guards(amount)
	EventBus.tip_requested.emit("TIP_GUARD_PICKED")
	set_deferred(&"monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
