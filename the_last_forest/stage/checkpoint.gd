class_name Checkpoint
extends Area2D
## Touch to set the respawn point (e.g. a sprouting stump or signpost).
## Mask = layer 1 "player".

signal activated

var _active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group(&"player"):
		return
	_active = true
	GameState.checkpoint_position = global_position
	activated.emit()
