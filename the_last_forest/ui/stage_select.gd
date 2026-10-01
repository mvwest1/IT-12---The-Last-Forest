extends Control
## Stage Select: 4 picture cards, unlocked in order per student (from SQLite).

@onready var _student: Label = %StudentLabel
@onready var _buttons: Array[Button] = [%Stage1Button, %Stage2Button, %Stage3Button, %Stage4Button]
@onready var _logout: Button = %LogoutButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	var who: String = AppFlow.student_display_name if AppFlow.student_display_name != "" else tr("STUDENT_GENERIC")
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
