extends Control
## Stage Select: 4 stage buttons, unlocked in order per student (from SQLite).

@onready var _student: Label = %StudentLabel
@onready var _buttons: Array[Button] = [%Stage1Button, %Stage2Button, %Stage3Button, %Stage4Button]
@onready var _logout: Button = %LogoutButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	var who: String = AppFlow.student_display_name if AppFlow.student_display_name != "" else tr("STUDENT_GENERIC")
	_student.text = "%s  •  %s" % [who, AppFlow.grade_section] if AppFlow.is_logged_in() else tr("GUEST_MODE")
	for i: int in _buttons.size():
		var index: int = i + 1
		var btn: Button = _buttons[i]
		var exists: bool = AppFlow.stage_exists(index)
		var unlocked: bool = AppFlow.is_stage_unlocked(index)
		btn.text = "%d. %s" % [index, tr(AppFlow.STAGE_TITLE_KEYS[i])]
		if not exists:
			btn.text += "\n" + tr("STAGE_COMING_SOON")
		elif not unlocked:
			btn.text += "\n" + tr("STAGE_LOCKED")
		btn.disabled = not (exists and unlocked)
		btn.pressed.connect(AppFlow.start_stage.bind(index))
	_logout.pressed.connect(AppFlow.logout)
	_back.pressed.connect(AppFlow.go_main_menu)
	for btn: Button in _buttons:
		if not btn.disabled:
			btn.grab_focus()
