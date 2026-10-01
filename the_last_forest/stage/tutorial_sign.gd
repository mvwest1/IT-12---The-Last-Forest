extends Area2D
class_name TutorialSign
## A "?" sign the child can read (press E) as many times as they like.
## prompt_title / prompt_message are TRANSLATION KEYS (ui.csv), so the
## English/Filipino toggle works. Plain text also works (shown as-is).

@export var prompt_title: String = ""
@export_multiline var prompt_message: String = ""

var _player_inside: bool = false
var _read_once: bool = false

@onready var _indicator: Label = $Indicator
@onready var _icon: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_indicator.text = tr("SIGN_PRESS_E")
	_indicator.hide()
	# Gentle bob on the "Press E" label (the wooden sign itself stays planted).
	var base_y: float = _indicator.position.y
	var tween := create_tween().set_loops()
	tween.tween_property(_indicator, "position:y", base_y - 4.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_indicator, "position:y", base_y, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside and event.is_action_pressed("interact"):
		_read_once = true
		_icon.modulate = Color(0.8, 0.8, 0.8)  # slightly dimmed = already read
		EventBus.climate_tip_triggered.emit({"title": prompt_title, "text": prompt_message})
		get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_indicator.show()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_indicator.hide()
