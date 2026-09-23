class_name PlayerInteractor
extends Area2D
## Add as a child of Player (with its own CollisionShape2D, ~48 px wide).
## Finds the nearest Interactable and runs the hold-to-interact state machine:
##
##   IDLE --(interact just pressed, on floor, allowed)--> HOLDING
##   HOLDING --(timer >= hold_time)--> complete -> IDLE
##   HOLDING --(released / moved / jumped / target gone)--> cancel -> IDLE
##
## Uses a dedicated "interact" action (E / gamepad Y), NOT ui_accept:
## in this project Space is "shoot" and ui_accept also drives UI buttons.

const ACTION: StringName = &"interact"

## Accessibility: tap once to start, tap again to cancel (for kids who
## struggle to keep a key held down).
@export var toggle_mode: bool = false
@export var cancel_move_threshold: float = 0.5

var _nearby: Array[Interactable] = []
var _target: Interactable = null
var _holding: bool = false
var _elapsed: float = 0.0

@onready var _player: CharacterBody2D = get_parent() as CharacterBody2D


func _ready() -> void:
	_ensure_input_action()
	collision_layer = 0
	collision_mask = Interactable.LAYER
	monitoring = true
	monitorable = false
	add_to_group(&"player_interactor")
	if _player != null:
		_player.add_to_group(&"player")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func is_busy() -> bool:
	return _holding


func _physics_process(delta: float) -> void:
	if _holding:
		_update_hold(delta)
		return
	_retarget()
	if _target != null and Input.is_action_just_pressed(ACTION):
		_try_begin()


func _try_begin() -> void:
	if _player != null and not _player.is_on_floor():
		return
	var reason: StringName = _target.get_block_reason(self)
	if reason != &"":
		EventBus.interaction_denied.emit(_target, reason)
		return
	_holding = true
	_elapsed = 0.0
	_target.on_interaction_started(self)
	EventBus.interaction_started.emit(_target)
	if _target.hold_time <= 0.0:
		_finish()


func _update_hold(delta: float) -> void:
	var keep: bool
	if toggle_mode:
		keep = not Input.is_action_just_pressed(ACTION)
	else:
		keep = Input.is_action_pressed(ACTION)
	var moving: bool = absf(Input.get_axis(&"move_left", &"move_right")) > cancel_move_threshold
	var target_ok: bool = is_instance_valid(_target) and _nearby.has(_target) and _target.is_interactable()
	if not keep or moving or Input.is_action_just_pressed(&"jump") or not target_ok:
		_cancel()
		return
	_elapsed += delta
	var ratio: float = clampf(_elapsed / _target.hold_time, 0.0, 1.0)
	EventBus.interaction_progress.emit(_target, ratio)
	if ratio >= 1.0:
		_finish()


func _finish() -> void:
	var done: Interactable = _target
	_holding = false
	_elapsed = 0.0
	done.complete_interaction(self)
	EventBus.interaction_completed.emit(done)
	_retarget()


func _cancel() -> void:
	_holding = false
	_elapsed = 0.0
	if is_instance_valid(_target):
		_target.on_interaction_cancelled(self)
		EventBus.interaction_cancelled.emit(_target)
	else:
		EventBus.interaction_cancelled.emit(null)
	_retarget()


func _retarget() -> void:
	var best: Interactable = null
	var best_dist: float = INF
	for candidate: Interactable in _nearby:
		if not is_instance_valid(candidate) or not candidate.is_interactable():
			continue
		var d: float = global_position.distance_squared_to(candidate.global_position)
		if d < best_dist:
			best_dist = d
			best = candidate
	if best == _target:
		return
	if is_instance_valid(_target):
		_target.set_highlighted(false)
	_target = best
	if _target != null:
		_target.set_highlighted(true)


func _on_area_entered(area: Area2D) -> void:
	if area is Interactable and not _nearby.has(area):
		_nearby.append(area as Interactable)


func _on_area_exited(area: Area2D) -> void:
	if area is Interactable:
		_nearby.erase(area as Interactable)
		if area == _target and not _holding:
			(area as Interactable).set_highlighted(false)
			_target = null


## Safety net: creates the "interact" action (E) if it is missing from the
## Input Map. Still add it properly in Project Settings (with a gamepad button).
static func _ensure_input_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION, 0.2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputMap.action_add_event(ACTION, key)
