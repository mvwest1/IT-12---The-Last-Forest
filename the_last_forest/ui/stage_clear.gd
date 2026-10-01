extends Control
## Stage Clear: shows results of AppFlow.last_result (already saved to SQLite).

@onready var _title: Label = %ClearTitle
@onready var _stats: Label = %StatsLabel
@onready var _quiz: Label = %QuizLabel
@onready var _saved: Label = %SavedLabel
@onready var _next: Button = %NextButton
@onready var _select: Button = %StageSelectButton
@onready var _stars: Array[TextureRect] = [%Star1, %Star2, %Star3]

const STAR_FULL: Texture2D = preload("res://the_last_forest/art/star_full.png")


func _ready() -> void:
	var r: Dictionary = AppFlow.last_result
	var index: int = int(r.get("stage_index", AppFlow.current_stage_index))
	var final_stage: bool = index >= AppFlow.STAGE_COUNT
	_title.text = tr("CLEAR_FINAL") if final_stage else tr("CLEAR_TITLE") % tr(AppFlow.STAGE_TITLE_KEYS[clampi(index, 1, 4) - 1])
	if final_stage and AppFlow.student_display_name != "":
		_title.text += "\n" + AppFlow.student_display_name
	var secs: int = roundi(float(r.get("duration", 0.0)))
	_stats.text = tr("CLEAR_STATS") % [int(r.get("trees_matured", 0)), int(r.get("seeds_collected", 0)), secs / 60, secs % 60]
	var total: int = int(r.get("quiz_total", 0))
	if total > 0 and int(r.get("post_score", -1)) >= 0:
		_quiz.text = tr("CLEAR_QUIZ") % [maxi(int(r.get("pre_score", 0)), 0), total, int(r.get("post_score", 0)), total]
	else:
		_quiz.text = ""
	if r.get("guest", true):
		_saved.text = tr("CLEAR_GUEST")
	else:
		_saved.text = tr("CLEAR_SAVED") if r.get("saved", false) else tr("CLEAR_SAVE_FAILED")
	# Stars = post-quiz score out of 3 (always at least 1 for finishing).
	var star_count: int = 3
	if total > 0 and int(r.get("post_score", -1)) >= 0:
		star_count = clampi(roundi(3.0 * float(r.get("post_score", 0)) / float(total)), 1, 3)
	for i: int in _stars.size():
		if i < star_count:
			_stars[i].texture = STAR_FULL
			_stars[i].pivot_offset = _stars[i].custom_minimum_size / 2.0
			_stars[i].scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.25 + 0.25 * i)
			tw.tween_property(_stars[i], ^"scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_next.visible = AppFlow.has_next_stage()
	_next.pressed.connect(func() -> void: AppFlow.start_stage(AppFlow.current_stage_index + 1))
	_select.pressed.connect(AppFlow.go_stage_select)
	(_next if _next.visible else _select).grab_focus()
