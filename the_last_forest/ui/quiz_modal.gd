class_name QuizModal
extends Control
## Pausing pre/post quiz. Opened only by LearningDirector.run_quiz().
##
## Research rules baked in:
##   * PRE-test gives NO right/wrong feedback (otherwise the pre-test teaches
##     the answers and inflates the post-test gain).
##   * POST-test shows the right answer gently; a wrong answer costs nothing.
##   * Choice order is shuffled per question to reduce position bias.
##   * Buttons ignore input for a short moment so button-mashing can't answer.

signal finished(score: int)

const INPUT_LOCK_SEC: float = 0.8
const FEEDBACK_SEC: float = 1.6

var _quiz: QuizSet = null
var _phase: StringName = &"pre"
var _index: int = 0
var _score: int = 0
var _order: Array[int] = []
var _locked: bool = true

@onready var _header: Label = %QuizHeader
@onready var _progress: Label = %QuizProgress
@onready var _prompt: Label = %QuizPrompt
@onready var _image: TextureRect = %QuizImage
@onready var _feedback: Label = %QuizFeedback
@onready var _buttons: Array[Button] = [%Choice1, %Choice2, %Choice3]
@onready var _score_tally: Label = %ScoreTally
@onready var _next_button: Button = %QuizNextButton
var _awaiting_continue: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	for i: int in _buttons.size():
		_buttons[i].pressed.connect(_on_choice.bind(i))
	LearningDirector.register_quiz_popup(self)
	_next_button.pressed.connect(_finish_quiz)


func present(quiz: QuizSet, phase: StringName) -> void:
	_quiz = quiz
	_phase = phase
	_index = 0
	_score = 0
	_awaiting_continue = false
	_score_tally.hide()
	_next_button.hide()
	for button: Button in _buttons:
		button.show()
	_header.text = tr("QUIZ_PRE_HEADER" if phase == &"pre" else "QUIZ_POST_HEADER")
	_next_button.text = "Continue" if phase == &"pre" else "Next Stage"
	show()
	_show_question()


func _show_question() -> void:
	var q: QuizQuestion = _quiz.questions[_index]
	_progress.text = "%d / %d" % [_index + 1, _quiz.questions.size()]
	_prompt.text = tr(q.prompt_key)
	_image.texture = q.image
	_image.visible = q.image != null
	_feedback.text = ""
	_order.clear()
	for i: int in q.choice_keys.size():
		_order.append(i)
	_order.shuffle()
	for b: int in _buttons.size():
		var btn: Button = _buttons[b]
		btn.visible = b < _order.size()
		btn.disabled = true
		btn.modulate = Color.WHITE
		if btn.visible:
			btn.text = tr(q.choice_keys[_order[b]])
	_locked = true
	await get_tree().create_timer(INPUT_LOCK_SEC, true).timeout
	_locked = false
	for btn: Button in _buttons:
		btn.disabled = false
	if _buttons[0].visible:
		_buttons[0].grab_focus()


func _on_choice(button_index: int) -> void:
	if _locked:
		return
	_locked = true
	var q: QuizQuestion = _quiz.questions[_index]
	var picked: int = _order[button_index]
	var correct: bool = picked == q.correct_index
	if correct:
		_score += 1
	for btn: Button in _buttons:
		btn.disabled = true
	if _phase == &"post":
		var right_button: int = _order.find(q.correct_index)
		_buttons[right_button].modulate = Color(0.6, 1.0, 0.6)
		_feedback.text = tr("QUIZ_RIGHT" if correct else "QUIZ_WRONG")
		await get_tree().create_timer(FEEDBACK_SEC, true).timeout
	else:
		_feedback.text = tr("QUIZ_THANKS")
		await get_tree().create_timer(0.4, true).timeout
	_index += 1
	if _index < _quiz.questions.size():
		_show_question()
	else:
		_show_score()


func _unhandled_input(_event: InputEvent) -> void:
	# Swallow gameplay input (jump/pause) while the quiz is open.
	if visible:
		get_viewport().set_input_as_handled()


func _show_score() -> void:
	_progress.text = "Assessment complete"
	_prompt.text = "Your answers help track what you learned about this ecosystem."
	_image.hide()
	_feedback.text = ""
	for button: Button in _buttons:
		button.hide()
	_score_tally.text = "Score: %d / %d" % [_score, _quiz.questions.size()]
	_score_tally.show()
	_next_button.show()
	_next_button.grab_focus()
	_awaiting_continue = true


func _finish_quiz() -> void:
	if not _awaiting_continue:
		return
	_awaiting_continue = false
	hide()
	finished.emit(_score)
