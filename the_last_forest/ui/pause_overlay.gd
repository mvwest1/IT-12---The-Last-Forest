class_name PauseOverlay
extends Control
## Esc / Start opens this. Uses GameState pause ownership (never touches
## get_tree().paused directly). Replaces the demo's pause_menu.gd, which had
## a coin counter, split-screen buttons and raw paused=false calls.

const OWNER: StringName = &"pause_menu"

@onready var _resume: Button = %ResumeButton
@onready var _stage_select: Button = %StageSelectButton
@onready var _hold_toggle: CheckButton = %HoldToggle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_resume.pressed.connect(close)
	_stage_select.pressed.connect(_on_stage_select)
	_hold_toggle.toggled.connect(_on_hold_toggled)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"toggle_pause"):
		return
	# A fact card or quiz owns the screen: the pause menu waits.
	if LearningDirector.is_showing() or GameState.is_paused_by(&"quiz"):
		return
	if visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	GameState.request_pause(OWNER)
	var interactor := get_tree().get_first_node_in_group(&"player_interactor") as PlayerInteractor
	if interactor != null:
		_hold_toggle.set_pressed_no_signal(interactor.toggle_mode)
	show()
	_resume.grab_focus()


func close() -> void:
	hide()
	GameState.release_pause(OWNER)


func _on_stage_select() -> void:
	hide()
	AppFlow.go_stage_select()


## Accessibility: tap E to start/stop instead of holding it.
func _on_hold_toggled(tap_mode: bool) -> void:
	var interactor := get_tree().get_first_node_in_group(&"player_interactor") as PlayerInteractor
	if interactor != null:
		interactor.toggle_mode = tap_mode
