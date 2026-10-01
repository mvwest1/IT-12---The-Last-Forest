class_name Checkpoint
extends Area2D
## Touch to set the respawn point (e.g. a sprouting stump or signpost).
## Mask = layer 1 "player".

signal activated

## Optional: texture swapped onto the "Sprite2D" child when touched.
@export var active_texture: Texture2D
## Respawn slightly above the ground line so the player never starts inside a tile.
@export var respawn_offset: Vector2 = Vector2(0, -42)

var _active: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _active or not body.is_in_group(&"player"):
		return
	_active = true
	GameState.checkpoint_position = global_position + respawn_offset
	var sprite := get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite != null and active_texture != null:
		sprite.texture = active_texture
		var tw := create_tween()
		tw.tween_property(sprite, ^"scale", Vector2(1.3, 1.3), 0.12)
		tw.tween_property(sprite, ^"scale", Vector2.ONE, 0.18)
	activated.emit()
