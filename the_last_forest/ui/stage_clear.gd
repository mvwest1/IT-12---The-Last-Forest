extends Control
## Stage Clear: shows results of AppFlow.last_result (already saved to SQLite).

@onready var _title: Label = %ClearTitle
@onready var _stats: Label = %StatsLabel
@onready var _quiz: Label = %QuizLabel
@onready var _saved: Label = %SavedLabel
@onready var _next: Button = %NextButton
@onready var _select: Button = %StageSelectButton


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
	_next.visible = AppFlow.has_next_stage()
	_next.pressed.connect(func() -> void: AppFlow.start_stage(AppFlow.current_stage_index + 1))
	_select.pressed.connect(AppFlow.go_stage_select)
	(_next if _next.visible else _select).grab_focus()
