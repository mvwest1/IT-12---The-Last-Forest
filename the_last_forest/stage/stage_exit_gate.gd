extends Area2D
class_name StageExitGate

@export var stage_controller_path: NodePath = ^"../StageController"

var _player_inside: bool = false
var _ready_to_clear: bool = false
var _submitted: bool = false

@onready var _controller: StageController = get_node_or_null(stage_controller_path) as StageController
@onready var _prompt: Label = $Prompt

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_prompt.hide()

func refresh_state(ready_to_clear: bool) -> void:
	_ready_to_clear = ready_to_clear
	if _player_inside:
		if _ready_to_clear:
			_prompt.hide()
			_complete.call_deferred()
		else:
			_prompt.text = "The forest is not fully restored yet! Wait for your saplings to grow."
			_prompt.show()

func _unhandled_input(event: InputEvent) -> void:
	if not _player_inside or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _ready_to_clear and _controller != null:
		_complete()
	else:
		_prompt.text = "The forest is not fully restored yet! Wait for your saplings to grow."
		_prompt.show()

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
