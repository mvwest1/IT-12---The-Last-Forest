class_name PauseOverlay
extends Control
## Esc / Start opens this. Uses GameState pause ownership (never touches
## get_tree().paused directly).
## Includes the Leaf Journal: re-read every fact card unlocked so far.

const OWNER: StringName = &"pause_menu"

var _journal_facts: Array[ClimateFact] = []
var _journal_index: int = 0

@onready var _card: Control = $Card
@onready var _resume: Button = %ResumeButton
@onready var _journal_button: Button = %JournalButton
@onready var _stage_select: Button = %StageSelectButton
@onready var _hold_toggle: CheckButton = %HoldToggle
@onready var _journal: Control = %JournalPanel
@onready var _j_title: Label = %JournalTitle
@onready var _j_image: TextureRect = %JournalImage
@onready var _j_body: Label = %JournalBody
@onready var _j_page: Label = %JournalPage
@onready var _j_prev: Button = %JournalPrev
@onready var _j_next: Button = %JournalNext
@onready var _j_close: Button = %JournalClose


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_journal.hide()
	_resume.pressed.connect(close)
	_journal_button.pressed.connect(_open_journal)
	_stage_select.pressed.connect(_on_stage_select)
	_hold_toggle.toggled.connect(_on_hold_toggled)
	_j_prev.pressed.connect(_turn_page.bind(-1))
	_j_next.pressed.connect(_turn_page.bind(1))
	_j_close.pressed.connect(_close_journal)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"toggle_pause"):
		return
	# A fact card, quiz or hint owns the screen: the pause menu waits.
	if LearningDirector.is_showing() or GameState.is_paused_by(&"quiz") or GameState.is_paused_by(&"climate_tip"):
		return
	if _journal.visible:
		_close_journal()
	elif visible:
		close()
	else:
		open()
	get_viewport().set_input_as_handled()


func open() -> void:
	GameState.request_pause(OWNER)
	var interactor := get_tree().get_first_node_in_group(&"player_interactor") as PlayerInteractor
	if interactor != null:
		_hold_toggle.set_pressed_no_signal(interactor.toggle_mode)
	_journal.hide()
	_card.show()
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


# ------------------------------------------------------------------ Leaf Journal
func _open_journal() -> void:
	_journal_facts = LearningDirector.get_unlocked_facts()
	_journal_index = _journal_facts.size() - 1  # newest first
	_card.hide()
	_journal.show()
	_show_page()


func _close_journal() -> void:
	_journal.hide()
	_card.show()
	_journal_button.grab_focus()


func _turn_page(step: int) -> void:
	if _journal_facts.is_empty():
		return
	_journal_index = wrapi(_journal_index + step, 0, _journal_facts.size())
	_show_page()


func _show_page() -> void:
	var empty: bool = _journal_facts.is_empty()
	_j_prev.disabled = _journal_facts.size() < 2
	_j_next.disabled = _journal_facts.size() < 2
	if empty:
		_j_title.text = ""
		_j_image.texture = null
		_j_body.text = tr("JOURNAL_EMPTY")
		_j_page.text = "0 / 0"
		_j_close.grab_focus()
		return
	var fact: ClimateFact = _journal_facts[_journal_index]
	_j_title.text = tr(fact.title_key)
	_j_image.texture = fact.image
	_j_body.text = tr(fact.body_key)
	_j_page.text = "%d / %d" % [_journal_index + 1, _journal_facts.size()]
	(_j_next if not _j_next.disabled else _j_close).grab_focus()
