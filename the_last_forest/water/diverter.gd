class_name Diverter
extends Interactable
## A lever on the ground that tilts a ramp (StaticBody2D) somewhere above it,
## sending the water stream left or right. Hold E briefly to flip.
##
## Scene (diverter.tscn):
##   Diverter (Area2D, this script) — the LEVER the player stands next to
##   ├─ CollisionShape2D
##   ├─ LeverSprite (Node2D/Polygon2D)   rotates to show the state
##   ├─ Prompt (Label)                  "Hold E to turn the water"
##   └─ Ramp (StaticBody2D)             layer 4 "platforms" — move it under the stream
##      ├─ CollisionShape2D (SegmentShape2D / thin RectangleShape2D)
##      └─ Polygon2D (visual)
## `angle_to_target` is the ramp angle that sends water to the AridZone.

@export var angle_to_target: float = 22.0
@export var angle_away: float = -22.0
@export var starts_pointing_to_target: bool = false

var points_to_target: bool = false

@onready var _ramp: Node2D = $Ramp
@onready var _lever: Node2D = get_node_or_null(^"LeverSprite") as Node2D


func _ready() -> void:
	super()
	hold_time = 0.4
	prompt_key = "PROMPT_DIVERTER"
	if _prompt is Label:
		(_prompt as Label).text = tr(prompt_key)
	points_to_target = starts_pointing_to_target
	_apply(false)


func complete_interaction(_interactor: Node) -> void:
	points_to_target = not points_to_target
	_apply(true)
	EventBus.diverter_toggled.emit(self, points_to_target)


func _apply(animate: bool) -> void:
	var angle: float = deg_to_rad(angle_to_target if points_to_target else angle_away)
	var lever_angle: float = deg_to_rad(30.0 if points_to_target else -30.0)
	if animate:
		var tween := create_tween().set_parallel()
		tween.tween_property(_ramp, ^"rotation", angle, 0.3).set_trans(Tween.TRANS_BACK)
		if _lever != null:
			tween.tween_property(_lever, ^"rotation", lever_angle, 0.2)
	else:
		_ramp.rotation = angle
		if _lever != null:
			_lever.rotation = lever_angle
