extends Area2D
class_name StageExitGate
## The stage exit. Opens only when the StageController says the goal is met.
## Walking in while open clears the stage; while closed it tells the child,
## in their language, how many trees still need to grow.

@export var stage_controller_path: NodePath = ^"../StageController"

var _player_inside: bool = false
var _ready_to_clear: bool = false
var _submitted: bool = false

@onready var _controller: StageController = get_node_or_null(stage_controller_path) as StageController
@onready var _prompt: Label = $Prompt
@onready var _visual: CanvasItem = get_node_or_null(^"Visual") as CanvasItem


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.hide()
	_update_visual()


func refresh_state(ready_to_clear: bool) -> void:
	_ready_to_clear = ready_to_clear
	_update_visual()
	if not _player_inside:
		return
	if _ready_to_clear:
		_prompt.hide()
		_complete.call_deferred()
	else:
		_show_not_ready()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not event.is_action_pressed("interact"):
		return
	if _ready_to_clear and _controller != null:
		get_viewport().set_input_as_handled()
		_complete()
	else:
		_show_not_ready()


func _show_not_ready() -> void:
	var remaining: int = maxi(0, GameState.tree_goal - GameState.trees_matured)
	if remaining > 0:
		_prompt.text = tr("GATE_NOT_READY") % remaining
	else:
		_prompt.text = tr("GATE_NOT_READY_HEALTH")
	_prompt.show()


func _update_visual() -> void:
	if _visual == null:
		return
	if _visual.has_method(&"set_open"):
		_visual.call(&"set_open", _ready_to_clear)
	else:
		_visual.modulate = Color(0.6, 1.0, 0.6) if _ready_to_clear else Color(0.6, 0.55, 0.5)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		refresh_state(_controller != null and _controller.can_clear_stage())


func _complete() -> void:
	if _submitted or not _player_inside or not _ready_to_clear or _controller == null:
		return
	_submitted = true
	_controller.request_stage_clear()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_prompt.hide()
