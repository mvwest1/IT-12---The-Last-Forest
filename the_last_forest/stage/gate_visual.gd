extends Sprite2D
## Exit-gate art: dry tangled vines while closed, glowing green portal when open.

const CLOSED: Texture2D = preload("res://the_last_forest/art/gate_closed.png")
const OPEN: Texture2D = preload("res://the_last_forest/art/gate_open.png")

var _is_open: bool = false

@onready var _glow: CPUParticles2D = get_node_or_null(^"Glow") as CPUParticles2D


func _ready() -> void:
	texture = CLOSED
	if _glow != null:
		_glow.emitting = false


func set_open(open_: bool) -> void:
	if open_ == _is_open:
		return
	_is_open = open_
	texture = OPEN if open_ else CLOSED
	if _glow != null:
		_glow.emitting = open_
	if open_:
		scale = Vector2(1.15, 0.9)
		create_tween().tween_property(self, ^"scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
