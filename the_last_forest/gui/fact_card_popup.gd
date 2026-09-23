class_name FactCardPopup
extends Control
## Pausing climate-fact card. Only LearningDirector opens it.
##
## Scene (fact_card_popup.tscn) — full-rect Control, process_mode = Always:
##   FactCardPopup (Control, this script)
##   ├─ Dim (ColorRect, black @ 60 %, full rect)
##   └─ Card (PanelContainer, centered, ~560x360 at 800x480)
##      └─ VBox (VBoxContainer)
##         ├─ Title (Label)            %Title   — big, 1 line
##         ├─ Image (TextureRect)      %Image   — picture first
##         ├─ Body (Label, autowrap)   %Body    — max ~25 words
##         └─ Buttons (HBoxContainer)
##            ├─ ListenButton (Button) %ListenButton  "Listen"
##            └─ CloseButton (Button)  %CloseButton   "Got it!"
##   └─ Voice (AudioStreamPlayer)      %Voice
## (Mark Title/Image/Body/buttons/Voice as "Access as Unique Name".)
##
## Anti-frustration:
##   * Close is disabled for MIN_READ_SEC so button-mashing can't skip it.
##   * Closes on RELEASE of "interact" (after a fresh press) or on click,
##     so the same key press can't also start planting when the game resumes.
##   * Jump/shoot are swallowed while the card is open.

signal closed

const MIN_READ_SEC: float = 1.5

var _can_close: bool = false
var _armed: bool = false
var _fact: ClimateFact = null

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _image: TextureRect = %Image
@onready var _close_button: Button = %CloseButton
@onready var _listen_button: Button = %ListenButton
@onready var _voice: AudioStreamPlayer = %Voice


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_close_button.text = tr("UI_GOT_IT")
	_listen_button.text = tr("UI_LISTEN")
	_close_button.pressed.connect(_close)
	_listen_button.pressed.connect(_play_voice)
	LearningDirector.register_popup(self)


func present(fact: ClimateFact) -> void:
	_fact = fact
	_title.text = tr(fact.title_key)
	_body.text = tr(fact.body_key)
	_image.texture = fact.image
	_image.visible = fact.image != null
	_listen_button.visible = fact.voice_over != null
	_can_close = false
	_armed = false
	_close_button.disabled = true
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, ^"modulate:a", 1.0, 0.25)
	if fact.voice_over != null:
		_play_voice()
	await get_tree().create_timer(MIN_READ_SEC, true).timeout
	_can_close = true
	_close_button.disabled = false
	_close_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _can_close and event.is_action_pressed(&"interact"):
		_armed = true
	elif _armed and event.is_action_released(&"interact"):
		_close()
	# Swallow everything else (jump, shoot, pause) while a card is open.
	get_viewport().set_input_as_handled()


func _play_voice() -> void:
	if _fact != null and _fact.voice_over != null:
		_voice.stream = _fact.voice_over
		_voice.play()


func _close() -> void:
	if not _can_close or not visible:
		return
	_can_close = false
	_voice.stop()
	var tween := create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, 0.15)
	tween.tween_callback(hide)
	tween.tween_callback(closed.emit)
