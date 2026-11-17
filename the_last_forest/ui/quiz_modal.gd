class_name QuizModal
extends Control
## Pausing pre/post quiz. Opened only by LearningDirector.run_quiz().
##
## Flow (designed for 8-10 year olds on a phone):
##   1. Intro page: stage name + what is about to happen + [Start]
##      (pre: "it's okay to guess"; post: "same 3 questions again")
##   2. Question: buttons fade in; the tapped answer lights up at once.
##        PRE  -> gold highlight + "Thank you!" (NO right/wrong: the pre-test
##                must not teach the answers, or the gain is inflated)
##        POST -> green = right answer, red = wrong pick + short message
##   3. Result page: post-test shows stars + score; pre-test only says thanks.
##
## Research rules: choice order is shuffled per question; a very short input
## lock (INPUT_LOCK_SEC) stops one tap from answering two questions, but the
## buttons never look "disabled", so a child is never left wondering why
## nothing happens.

signal finished(score: int)

const INPUT_LOCK_SEC: float = 0.35
const PRE_FEEDBACK_SEC: float = 0.7
const FEEDBACK_SEC: float = 1.6
const PICKED := Color(1.25, 1.12, 0.6)
const RIGHT := Color(0.8, 1.2, 0.75)
const WRONG := Color(1.2, 0.72, 0.66)
const STAR_FULL: Texture2D = preload("res://the_last_forest/art/star_full.png")
const STAR_EMPTY: Texture2D = preload("res://the_last_forest/art/star_empty.png")

var _quiz: QuizSet = null
var _phase: StringName = &"pre"
var _index: int = 0
var _score: int = 0
var _order: Array[int] = []
var _locked: bool = true
var _awaiting_continue: bool = false
## True while the intro page (with the Start button) is showing.
var _awaiting_start: bool = false
var _stars: HBoxContainer = null

@onready var _header: Label = %QuizHeader
@onready var _progress: Label = %QuizProgress
@onready var _prompt: Label = %QuizPrompt
@onready var _image: TextureRect = %QuizImage
@onready var _feedback: Label = %QuizFeedback
@onready var _buttons: Array[Button] = [%Choice1, %Choice2, %Choice3]
@onready var _score_tally: Label = %ScoreTally
@onready var _next_button: Button = %QuizNextButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	for i: int in _buttons.size():
		_buttons[i].pressed.connect(_on_choice.bind(i))
		_buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_buttons[i].custom_minimum_size.y = 56
		_buttons[i].add_theme_font_size_override("font_size", 22)
	_next_button.pressed.connect(_on_next_pressed)
	_stars = HBoxContainer.new()
	_stars.alignment = BoxContainer.ALIGNMENT_CENTER
	_stars.add_theme_constant_override("separation", 10)
	for i: int in 3:
		var t := TextureRect.new()
		t.custom_minimum_size = Vector2(44, 44)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.pivot_offset = Vector2(22, 22)
		_stars.add_child(t)
	_score_tally.add_sibling(_stars)
	_stars.hide()
	LearningDirector.register_quiz_popup(self)


func present(quiz: QuizSet, phase: StringName) -> void:
	_quiz = quiz
	_phase = phase
	_index = 0
	_score = 0
	_awaiting_continue = false
	_awaiting_start = true
	_locked = true
	_header.text = tr("QUIZ_PRE_HEADER" if phase == &"pre" else "QUIZ_POST_HEADER")
	var stage_i: int = clampi(quiz.stage_index, 1, AppFlow.STAGE_COUNT)
	_progress.text = tr("QUIZ_STAGE_LABEL") % [stage_i, tr(AppFlow.STAGE_TITLE_KEYS[stage_i - 1])]
	_prompt.text = tr("QUIZ_PRE_INTRO" if phase == &"pre" else "QUIZ_POST_INTRO")
	_image.hide()
	_feedback.text = ""
	_score_tally.hide()
	_stars.hide()
	for button: Button in _buttons:
		button.hide()
	_next_button.text = tr("QUIZ_START")
	_next_button.show()
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, ^"modulate:a", 1.0, 0.2)
	_next_button.grab_focus()


func _on_next_pressed() -> void:
	if _awaiting_start:
		start_questions()
	else:
		_finish_quiz()


## Leaves the intro page and shows question 1.
func start_questions() -> void:
	if not _awaiting_start:
		return
	_awaiting_start = false
	_next_button.hide()
	_show_question()


func _show_question() -> void:
	var q: QuizQuestion = _quiz.questions[_index]
	_progress.text = "%d / %d   •   %s" % [_index + 1, _quiz.questions.size(), tr("QUIZ_TAP_HINT")]
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
		btn.disabled = false
		btn.modulate = Color(1, 1, 1, 0)
		if btn.visible:
			btn.text = tr(q.choice_keys[_order[b]])
			var tw := create_tween()
			tw.tween_interval(0.05 * b)
			tw.tween_property(btn, ^"modulate:a", 1.0, 0.2)
	_locked = true
	await get_tree().create_timer(INPUT_LOCK_SEC, true).timeout
	_locked = false
	if _buttons[0].visible:
		_buttons[0].grab_focus()


func _on_choice(button_index: int) -> void:
	if _locked or _awaiting_start or _awaiting_continue:
		return
	_locked = true
	var q: QuizQuestion = _quiz.questions[_index]
	var picked: int = _order[button_index]
	var correct: bool = picked == q.correct_index
	if correct:
		_score += 1
	for btn: Button in _buttons:
		btn.release_focus()
	if _phase == &"post":
		var right_button: int = _order.find(q.correct_index)
		if not correct:
			_buttons[button_index].modulate = WRONG
		_buttons[right_button].modulate = RIGHT
		_feedback.text = tr("QUIZ_RIGHT" if correct else "QUIZ_WRONG")
		await get_tree().create_timer(FEEDBACK_SEC, true).timeout
	else:
		_buttons[button_index].modulate = PICKED
		_feedback.text = tr("QUIZ_THANKS")
		await get_tree().create_timer(PRE_FEEDBACK_SEC, true).timeout
	if not visible:
		return
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
	_progress.text = tr("QUIZ_DONE")
	# Pre-test: no score shown (it would cue the answers / discourage).
	# Post-test: stars + score as positive feedback.
	_prompt.text = tr("QUIZ_PRE_DONE") if _phase == &"pre" else tr("QUIZ_POST_DONE")
	_image.hide()
	_feedback.text = ""
	for button: Button in _buttons:
		button.hide()
	var total: int = _quiz.questions.size()
	_score_tally.text = tr("QUIZ_SCORE") % [_score, total]
	_score_tally.visible = _phase == &"post"
	_stars.visible = _phase == &"post"
	if _stars.visible:
		var earned: int = roundi(3.0 * float(_score) / float(maxi(total, 1)))
		for i: int in 3:
			var t := _stars.get_child(i) as TextureRect
			t.texture = STAR_FULL if i < earned else STAR_EMPTY
			t.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.15 + 0.2 * i)
			tw.tween_property(t, ^"scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_next_button.text = tr("QUIZ_CONTINUE")
	_next_button.show()
	_next_button.grab_focus()
	_awaiting_continue = true


func _finish_quiz() -> void:
	if not _awaiting_continue:
		return
	_awaiting_continue = false
	hide()
	finished.emit(_score)
