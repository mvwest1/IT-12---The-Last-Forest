class_name Hazard
extends Area2D
## Anything that costs a heart on touch: embers (Stage 1), thorns, etc.
## The demo's player is invincible, so this + GameState is the whole health
## system. Mask = layer 1 "player".

@export var damage: int = 1
@export var knockback: Vector2 = Vector2(260, -420)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player") or GameState.is_invulnerable():
		return
	GameState.damage_player(damage)
	if body is CharacterBody2D:
		var cb := body as CharacterBody2D
		var dir: float = signf(cb.global_position.x - global_position.x)
		cb.velocity = Vector2(knockback.x * (dir if dir != 0.0 else 1.0), knockback.y)
