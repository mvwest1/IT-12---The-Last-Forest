extends Area2D
class_name TutorialSign

@export var prompt_title: String = ""
@export_multiline var prompt_message: String = ""

var _player_inside: bool = false
var _used: bool = false

@onready var _indicator: Label = $Indicator
@onready var _icon: Sprite2D = $Sprite2D

func _ready() -> void:
	collision_layer = 1 << 5
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_indicator.hide()
	var tween := create_tween().set_loops()
	tween.tween_property(_icon, "position:y", -31.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_icon, "position:y", -26.0, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and not _used and event.is_action_pressed("interact"):
		_used = true
		_indicator.hide()
		EventBus.climate_tip_triggered.emit({"title": prompt_title, "text": prompt_message})
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_indicator.visible = not _used

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_indicator.hide()
