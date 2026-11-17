class_name Pest
extends Area2D
## Leaf pest (Stage 2) — NON-LETHAL. Two looks from one script:
##   * leaf beetle  (default)        — flies, 2-frame wing animation
##   * caterpillar  (crawler = true) — snaps to the ground and inches along it
## Original note: flying insect pest — NON-LETHAL. Replaces the demo's Enemy and
## the bullet-kills-enemy loop. Pests seek the nearest vulnerable sapling and
## nibble it. They are never killed:
##   * Bump into a pest (walk or jump through it)  -> it gets shooed and flies away.
##   * Fence a sapling with a Tree Guard           -> pests ignore that sapling.
## Pests never hurt the player (the lesson is protecting trees, not combat).
##
## Scene (pest.tscn):
##   Pest (Area2D, this script)   layer 7 "pests", mask 1 "player"
##   ├─ Sprite2D
##   └─ CollisionShape2D (circle r≈8)
##
## States: SEEKING -> EATING -> (target gone/guarded) SEEKING ; any -> FLEEING -> freed

enum State { SEEKING, EATING, FLEEING }

const LAYER: int = 1 << 6   # physics layer 7 "pests"
const PLAYER_MASK: int = 1  # physics layer 1 "player"

@export var speed: float = 55.0
@export var bite_damage: int = 1
@export var bite_interval: float = 1.5
@export var bite_range: float = 14.0
@export var flee_speed: float = 260.0
@export var patrol_range: float = 70.0
## Caterpillar mode: walks on the ground instead of flying.
@export var crawler: bool = false

const BEETLE_TEX: Texture2D = preload("res://the_last_forest/art/beetle.png")
const CATERPILLAR_TEX: Texture2D = preload("res://the_last_forest/art/caterpillar.png")
const GROUND_MASK: int = (1 << 3) | (1 << 4)  # layers 4 "platforms" + 5 "ground"

var _state: State = State.SEEKING
var _target: Sapling = null
var _bite_timer: float = 0.0
var _wobble: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _patrol_origin_x: float = 0.0
var _patrol_direction: float = 1.0
var _grounded: bool = false
var _anim_t: float = 0.0

@onready var _sprite: CanvasItem = get_node_or_null(^"Sprite2D") as CanvasItem


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = PLAYER_MASK
	monitoring = true
	body_entered.connect(_on_body_entered)
	add_to_group(&"pests")
	_wobble = randf() * TAU
	_patrol_origin_x = global_position.x
	var spr := _sprite as Sprite2D
	if spr != null:
		spr.texture = CATERPILLAR_TEX if crawler else BEETLE_TEX
		spr.hframes = 2
		spr.scale = Vector2(1.3, 1.3)
	if crawler:
		speed *= 0.6
	EventBus.pest_spawned.emit(self)


## Caterpillars drop onto the ground below their spawn point (first physics frame).
func _snap_to_ground() -> void:
	_grounded = true
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, 600), GROUND_MASK)
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		crawler = false  # nothing to crawl on: behave like a beetle
		var spr := _sprite as Sprite2D
		if spr != null:
			spr.texture = BEETLE_TEX
		return
	global_position.y = (hit["position"] as Vector2).y - 7.0


func _physics_process(delta: float) -> void:
	if crawler and not _grounded:
		_snap_to_ground()
	_wobble += delta * 6.0
	match _state:
		State.SEEKING:
			if not _target_ok():
				_target = _find_target()
			if _target == null:
				if global_position.x >= _patrol_origin_x + patrol_range:
					_patrol_direction = -1.0
				elif global_position.x <= _patrol_origin_x - patrol_range:
					_patrol_direction = 1.0
				_velocity = Vector2(_patrol_direction * speed * 0.35, sin(_wobble) * 10.0)
			else:
				var to_target: Vector2 = _target.global_position + Vector2(0, -10) - global_position
				if crawler and _state != State.FLEEING:
					to_target.y = 0.0
				if to_target.length() <= bite_range:
					_state = State.EATING
					_bite_timer = bite_interval * 0.5
					_velocity = Vector2.ZERO
				else:
					_velocity = to_target.normalized() * speed + Vector2(0.0, sin(_wobble) * 20.0)
		State.EATING:
			_velocity = Vector2(0.0, sin(_wobble) * 6.0)
			if not _target_ok():
				_state = State.SEEKING
			else:
				_bite_timer -= delta
				if _bite_timer <= 0.0:
					_bite_timer = bite_interval
					_target.take_damage(bite_damage)
		State.FLEEING:
			pass
	if crawler and _state != State.FLEEING:
		_velocity.y = 0.0
	global_position += _velocity * delta
	_anim_t += delta * (10.0 if not crawler else 4.0)
	var spr := _sprite as Sprite2D
	if spr != null:  # 2-frame wing flap / inch-worm crawl
		spr.frame = int(_anim_t) % 2
	if _sprite is Node2D and absf(_velocity.x) > 1.0:
		(_sprite as Node2D).scale.x = signf(_velocity.x) * absf((_sprite as Node2D).scale.x)


## Non-lethal repel. Safe to call more than once.
func repel(from_position: Vector2) -> void:
	if _state == State.FLEEING:
		return
	_state = State.FLEEING
	remove_from_group(&"pests")
	set_deferred(&"monitoring", false)
	var away: float = signf(global_position.x - from_position.x)
	_velocity = Vector2(away if away != 0.0 else 1.0, -1.2).normalized() * flee_speed
	EventBus.pest_repelled.emit(self)
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		repel(body.global_position)


func _target_ok() -> bool:
	return _target != null and is_instance_valid(_target) and _target.is_vulnerable()


func _find_target() -> Sapling:
	var best: Sapling = null
	var best_d: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"saplings"):
		var s := node as Sapling
		if s == null or not s.is_vulnerable():
			continue
		if crawler and absf(s.global_position.y - global_position.y) > 48.0:
			continue
		var d: float = global_position.distance_squared_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best
