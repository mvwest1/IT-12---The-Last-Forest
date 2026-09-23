class_name Pest
extends CharacterBody2D
## Flying insect pest (Stage 2). Seeks the nearest vulnerable sapling and
## nibbles it. When hit by the player's projectile it FLEES (flies away)
## instead of dying — framing for young players is "shoo the pests away",
## and the fact cards explain natural helpers (ladybugs, birds).
##
## Scene (pest.tscn):
##   Pest (CharacterBody2D, this script)
##     collision_layer = layer 7 "pests"   (NOT layer 2 — the player's
##                                          mask includes layer 2 and would
##                                          bump into bugs)
##     collision_mask  = 0                  (flies through terrain)
##   ├─ AnimatedSprite2D (flap)
##   └─ CollisionShape2D (small circle)
## Add layer 7 to the bullet's collision_mask (26 -> 90) and apply the
## bullet.gd patch from the architecture doc.
##
## States: SEEKING -> EATING -> (target gone) SEEKING ; any -> FLEEING -> freed

enum State { SEEKING, EATING, FLEEING }

@export var speed: float = 55.0
@export var bite_damage: int = 1
@export var bite_interval: float = 1.5
@export var bite_range: float = 14.0
@export var flee_speed: float = 260.0

var _state: State = State.SEEKING
var _target: Sapling = null
var _bite_timer: float = 0.0
var _wobble: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"pests")
	EventBus.pest_spawned.emit(self)


func _physics_process(delta: float) -> void:
	_wobble += delta * 6.0
	match _state:
		State.SEEKING:
			if not _target_ok():
				_target = _find_target()
			if _target == null:
				velocity = Vector2(0.0, sin(_wobble) * 10.0)
			else:
				var to_target: Vector2 = _target.global_position + Vector2(0, -10) - global_position
				if to_target.length() <= bite_range:
					_state = State.EATING
					_bite_timer = bite_interval * 0.5
					velocity = Vector2.ZERO
				else:
					velocity = to_target.normalized() * speed + Vector2(0.0, sin(_wobble) * 20.0)
		State.EATING:
			velocity = Vector2(0.0, sin(_wobble) * 6.0)
			if not _target_ok():
				_state = State.SEEKING
			else:
				_bite_timer -= delta
				if _bite_timer <= 0.0:
					_bite_timer = bite_interval
					_target.take_damage(bite_damage)
		State.FLEEING:
			velocity = Vector2(signf(velocity.x + 0.01), -1.0).normalized() * flee_speed
	move_and_slide()


## Called by the patched bullet.gd.
func on_projectile_hit() -> void:
	if _state == State.FLEEING:
		return
	_state = State.FLEEING
	remove_from_group(&"pests")
	collision_layer = 0
	EventBus.pest_removed.emit(self)
	get_tree().create_timer(1.5).timeout.connect(queue_free)


func _target_ok() -> bool:
	return _target != null and is_instance_valid(_target) and _target.is_vulnerable()


func _find_target() -> Sapling:
	var best: Sapling = null
	var best_d: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"saplings"):
		var s := node as Sapling
		if s == null or not s.is_vulnerable():
			continue
		var d: float = global_position.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best
