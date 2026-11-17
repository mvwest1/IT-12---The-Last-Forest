extends Control
## Stage Select: 4 picture cards, unlocked in order per student (from SQLite).

@onready var _student: Label = %StudentLabel
@onready var _buttons: Array[Button] = [%Stage1Button, %Stage2Button, %Stage3Button, %Stage4Button]
@onready var _logout: Button = %LogoutButton
@onready var _back: Button = %BackButton
@onready var _records_button: Button = %RecordsButton
@onready var _records_panel: Control = %RecordsPanel
@onready var _records_grid: GridContainer = %RecordsGrid
@onready var _records_empty: Label = %RecordsEmpty
@onready var _records_source: Label = %RecordsSource
@onready var _records_close: Button = %RecordsClose


func _ready() -> void:
	var who: String = AppFlow.display_name()
	_student.text = "%s  •  %s" % [who, AppFlow.grade_section] if AppFlow.is_logged_in() else tr("GUEST_MODE")
	var highest: int = GameState.highest_completed_stage
	if AppFlow.is_logged_in():
		highest = maxi(highest, DatabaseManager.get_highest_completed_stage(AppFlow.student_id))
	for i: int in _buttons.size():
		var index: int = i + 1
		var btn: Button = _buttons[i]
		var exists: bool = AppFlow.stage_exists(index)
		var unlocked: bool = AppFlow.is_stage_unlocked(index)
		var status: String
		if not exists:
			status = tr("STAGE_COMING_SOON")
		elif not unlocked:
			status = tr("STAGE_LOCKED")
		elif index <= highest:
			status = tr("STAGE_DONE")
		else:
			status = tr("STAGE_PLAY")
		btn.text = "%d. %s  —  %s" % [index, tr(AppFlow.STAGE_TITLE_KEYS[i]), status]
		btn.disabled = not (exists and unlocked)
		btn.modulate = Color(1, 1, 1) if not btn.disabled else Color(0.75, 0.75, 0.75)
		btn.pressed.connect(AppFlow.start_stage.bind(index))
	_records_button.pressed.connect(_open_records)
	var story := Button.new()
	story.text = tr("SELECT_STORY")
	story.custom_minimum_size = Vector2(0, _records_button.custom_minimum_size.y)
	story.pressed.connect(func() -> void:
		AppFlow.story_return = AppFlow.STAGE_SELECT
		AppFlow.goto(AppFlow.STORY))
	_records_button.add_sibling(story)
	_records_close.pressed.connect(_close_records)
	_logout.pressed.connect(AppFlow.logout)
	_back.pressed.connect(AppFlow.go_main_menu)
	# Focus the next stage to play (first unlocked, not yet restored).
	var focus_btn: Button = null
	for i: int in _buttons.size():
		if not _buttons[i].disabled:
			focus_btn = _buttons[i]
			if i + 1 > highest:
				break
	if focus_btn != null:
		focus_btn.grab_focus()



# ------------------------------------------------------------------ My Records
## RETRIEVE + DISPLAY: reads this student's saved attempts back from the
## database (DatabaseManager.get_student_records) and shows them in a table.
func _open_records() -> void:
	for child: Node in _records_grid.get_children():
		child.queue_free()
	var from_db: bool = DatabaseManager.is_available()
	_records_source.text = tr("RECORDS_SOURCE_DB") if from_db else tr("RECORDS_SOURCE_BACKUP")
	var rows: Array[Dictionary] = []
	if AppFlow.is_logged_in():
		rows = DatabaseManager.get_student_records(AppFlow.student_id)
	_records_empty.text = tr("RECORDS_EMPTY" if AppFlow.is_logged_in() else "RECORDS_GUEST")
	_records_empty.visible = rows.is_empty()
	_records_grid.visible = not rows.is_empty()
	if not rows.is_empty():
		for key: String in ["RECORDS_COL_STAGE", "RECORDS_COL_QUIZ", "RECORDS_COL_TREES",
				"RECORDS_COL_SEEDS", "RECORDS_COL_TIME", "RECORDS_COL_DATE"]:
			_add_cell(tr(key), true)
		for row: Dictionary in rows:
			var stage: int = int(row.get("stage_index", 0))
			var title: String = tr(AppFlow.STAGE_TITLE_KEYS[clampi(stage - 1, 0, 3)])
			_add_cell("%d. %s" % [stage, title])
			var pre: String = _score(row.get("pre_score"))
			var post: String = _score(row.get("post_score"))
			_add_cell("%s → %s / 3" % [pre, post])
			_add_cell(str(int(row.get("trees_matured", 0))))
			_add_cell(str(int(row.get("seeds_collected", 0))))
			_add_cell(_clock(float(row.get("completion_time", 0.0))))
			_add_cell(str(row.get("completed_at", "")).left(16))
	_records_panel.show()
	_records_close.grab_focus()


func _close_records() -> void:
	_records_panel.hide()
	_records_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _records_panel.visible and event.is_action_pressed(&"ui_cancel"):
		_close_records()
		get_viewport().set_input_as_handled()


func _add_cell(text: String, header: bool = false) -> void:
	var label := Label.new()
	label.text = text
	if header:
		label.theme_type_variation = &"HudLabel"
		label.add_theme_font_size_override(&"font_size", 15)
	else:
		label.add_theme_font_size_override(&"font_size", 15)
	_records_grid.add_child(label)


static func _score(value: Variant) -> String:
	return "–" if value == null else str(int(value))


static func _clock(seconds: float) -> String:
	var s: int = int(round(seconds))
	return "%d:%02d" % [s / 60, s % 60]


## Android Back: close My Records first, otherwise go to the main menu.
func handle_back() -> bool:
	if _records_panel.visible:
		_close_records()
		return true
	return false
