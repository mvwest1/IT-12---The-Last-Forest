extends Control
## Stage Clear: shows results of AppFlow.last_result (saved to SQLite, or
## offers Retry if persistence failed).

@onready var _title: Label = %ClearTitle
@onready var _stats: Label = %StatsLabel
@onready var _quiz: Label = %QuizLabel
@onready var _saved: Label = %SavedLabel
@onready var _retry: Button = %RetryButton
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
	_show_points(r)
	_retry.pressed.connect(_on_retry_pressed)
	_next.pressed.connect(func() -> void: AppFlow.start_stage(AppFlow.current_stage_index + 1))
	_select.pressed.connect(AppFlow.go_stage_select)
	_refresh_save_state()


func _on_retry_pressed() -> void:
	AppFlow.retry_save()
	_refresh_save_state()


func _refresh_save_state() -> void:
	var r: Dictionary = AppFlow.last_result
	var index: int = clampi(int(r.get("stage_index", AppFlow.current_stage_index)), 1, AppFlow.STAGE_COUNT)
	var is_guest: bool = bool(r.get("guest", not AppFlow.is_logged_in()))
	var is_saved: bool = bool(r.get("saved", false))
	if is_guest:
		_saved.text = tr("CLEAR_GUEST")
	else:
		_saved.text = tr("CLEAR_SAVED") if is_saved else tr("CLEAR_SAVE_FAILED")
	_retry.visible = (not is_guest) and (not is_saved)
	_next.visible = (is_saved or is_guest) and AppFlow.has_next_stage() and AppFlow.is_stage_unlocked(index + 1)
	if _retry.visible:
		_retry.grab_focus()
	elif _next.visible:
		_next.grab_focus()
	else:
		_select.grab_focus()


## Forest Points earned (and leaderboard rank once saved).
func _show_points(r: Dictionary) -> void:
	var pts: int = int(r.get("score", 0))
	var line: String = tr("CLEAR_POINTS") % pts
	if bool(r.get("saved", false)) and pts > int(r.get("previous_best", 0)):
		line += "   ★ " + tr("CLEAR_NEW_BEST")
	if bool(r.get("saved", false)) and AppFlow.is_logged_in():
		var me: Dictionary = DatabaseManager.get_leaderboard_entry(AppFlow.student_id)
		if not me.is_empty():
			line += "\n" + tr("CLEAR_RANK") % int(me["rank"])
	var l := Label.new()
	l.name = "PointsLabel"
	l.text = line
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", UiKit.GOLD)
	_quiz.add_sibling(l)
	l.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(l, ^"scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
