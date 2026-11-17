extends Control
## Main Menu: Play / Leaf Journal / Leaderboard / Settings / Teacher / Quit.
##
## Teacher panel (PIN-protected; children never see class data):
##   first launch on a device -> create a PIN (stored only as a salted hash)
##   locked                   -> enter PIN (5 wrong tries = 30 s lockout)
##   unlocked                 -> class dashboard (per-stage averages),
##                               export CSV file / copy CSV, change PIN
## Every export is PIN-checked again inside DatabaseManager, not only here.

@onready var _play: Button = %PlayButton
@onready var _journal: Button = %JournalButton
@onready var _leaderboard: Button = %LeaderboardButton
@onready var _settings: Button = %SettingsButton
@onready var _teacher: Button = %TeacherButton
@onready var _quit: Button = %QuitButton
@onready var _db_status: Label = %DbStatus
@onready var _badge: Label = %PlayerBadge

var _teacher_panel: Control
var _pin: LineEdit
var _pin_confirm: LineEdit
var _teacher_title: Label
var _teacher_status: Label
var _primary: Button
var _dashboard: VBoxContainer
var _summary_label: Label
var _summary_grid: GridContainer
var _export: Button
var _copy: Button
var _open_folder: Button
var _change_pin: Button
var _close_teacher: Button
var _mode: StringName = &"locked"


func _ready() -> void:
	_play.pressed.connect(_on_play)
	_journal.pressed.connect(AppFlow.goto.bind(AppFlow.JOURNAL))
	_leaderboard.pressed.connect(AppFlow.goto.bind(AppFlow.LEADERBOARD))
	_settings.pressed.connect(AppFlow.goto.bind(AppFlow.SETTINGS))
	_teacher.pressed.connect(_on_teacher)
	_quit.pressed.connect(get_tree().quit)
	# Phones and tablets have no "Quit" convention (Home/Back does that).
	_quit.visible = not UiKit.is_mobile()
	_build_teacher_panel()
	_refresh_status_label()
	_refresh_badge()
	_play.grab_focus()


## Android Back: close the teacher panel if it is open.
func handle_back() -> bool:
	if _teacher_panel.visible:
		_close_teacher_panel()
		return true
	return false


func _on_play() -> void:
	if not Settings.story_seen:
		AppFlow.goto(AppFlow.STORY)
	elif AppFlow.is_logged_in():
		AppFlow.go_stage_select()
	else:
		AppFlow.go_login()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_status_label()
		_refresh_badge()


func _refresh_status_label() -> void:
	var db_text: String = tr("DB_OK") if DatabaseManager.is_available() else tr("DB_FALLBACK")
	_db_status.text = "v%s  •  %s" % [AppFlow.get_version(), db_text]


func _refresh_badge() -> void:
	if AppFlow.is_logged_in():
		var who: String = AppFlow.display_name()
		if AppFlow.nickname != "" and AppFlow.learner_code != "":
			who += " (%s)" % AppFlow.learner_code
		_badge.text = tr("MENU_PLAYING_AS") % who + "  •  " + AppFlow.grade_section
	else:
		_badge.text = tr("MENU_NOT_SIGNED_IN")


# ================================================================== Teacher panel
func _build_teacher_panel() -> void:
	_teacher_panel = Control.new()
	_teacher_panel.name = "TeacherPanel"
	_teacher_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_teacher_panel)
	var box: VBoxContainer = UiKit.modal(_teacher_panel, Vector2(600, 0))
	_teacher_title = UiKit.title(tr("TEACHER_TITLE"), 28)
	box.add_child(_teacher_title)
	_pin = _pin_field(tr("TEACHER_PIN"))
	box.add_child(_pin)
	_pin_confirm = _pin_field(tr("TEACHER_CONFIRM"))
	box.add_child(_pin_confirm)
	_teacher_status = UiKit.label("", 16)
	_teacher_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_teacher_status)
	# Dashboard (hidden until unlocked)
	_dashboard = VBoxContainer.new()
	_dashboard.add_theme_constant_override("separation", 6)
	box.add_child(_dashboard)
	_summary_label = UiKit.label("", 16, &"SubtleLabel")
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dashboard.add_child(_summary_label)
	_summary_grid = GridContainer.new()
	_summary_grid.columns = 6
	_summary_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_summary_grid.add_theme_constant_override("h_separation", 18)
	_dashboard.add_child(_summary_grid)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	_dashboard.add_child(actions)
	_export = UiKit.button(tr("TEACHER_EXPORT"), _on_export, Vector2(0, 42))
	_copy = UiKit.button(tr("TEACHER_COPY"), _on_copy_csv, Vector2(0, 42))
	_open_folder = UiKit.button(tr("TEACHER_OPEN_FOLDER"), _on_open_folder, Vector2(0, 42))
	_change_pin = UiKit.button(tr("TEACHER_CHANGE_PIN"), _on_change_pin, Vector2(0, 42))
	for b: Button in [_export, _copy, _open_folder, _change_pin]:
		b.add_theme_font_size_override("font_size", 16)
		actions.add_child(b)
	# The app folder on Android/iOS is private: copy-to-clipboard instead.
	_export.visible = not UiKit.is_mobile()
	_open_folder.visible = not UiKit.is_mobile()
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	box.add_child(bottom)
	_close_teacher = UiKit.button(tr("UI_CLOSE"), _close_teacher_panel, Vector2(140, 44))
	_primary = UiKit.button(tr("TEACHER_UNLOCK"), _on_primary, Vector2(180, 44))
	bottom.add_child(_close_teacher)
	bottom.add_child(_primary)
	_pin.text_submitted.connect(_on_pin_submitted)
	_pin_confirm.text_submitted.connect(func(_t: String) -> void: _on_primary())
	_teacher_panel.hide()


func _on_pin_submitted(_t: String) -> void:
	if _pin_confirm.visible:
		_pin_confirm.grab_focus()
	else:
		_on_primary()


func _pin_field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.secret = true
	e.max_length = LocalSettings.MAX_PIN_LEN
	e.placeholder_text = placeholder
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size = Vector2(260, 44)
	e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return e


func _set_mode(mode: StringName) -> void:
	_mode = mode
	var entering: bool = mode != &"dashboard"
	_pin.visible = entering
	_pin_confirm.visible = mode == &"setup" or mode == &"change"
	_primary.visible = entering
	_dashboard.visible = not entering
	if entering:
		_pin.text = ""
	_pin_confirm.text = ""
	match mode:
		&"setup":
			_teacher_title.text = tr("TEACHER_TITLE")
			_teacher_status.text = tr("TEACHER_SETUP")
			_pin.placeholder_text = tr("TEACHER_PIN")
			_primary.text = tr("TEACHER_SAVE_PIN")
		&"change":
			_teacher_title.text = tr("TEACHER_CHANGE_PIN")
			_teacher_status.text = tr("TEACHER_NEW_PIN")
			_pin.placeholder_text = tr("TEACHER_NEW_PIN")
			_primary.text = tr("TEACHER_SAVE_PIN")
		&"locked":
			_teacher_title.text = tr("TEACHER_TITLE")
			_teacher_status.text = tr("TEACHER_ENTER_PIN")
			_pin.placeholder_text = tr("TEACHER_PIN")
			_primary.text = tr("TEACHER_UNLOCK")
		&"dashboard":
			_teacher_title.text = tr("TEACHER_DASH")
			_teacher_status.text = ""
			_fill_dashboard()
	if entering:
		_pin.grab_focus()
	else:
		(_copy if UiKit.is_mobile() else _export).grab_focus()


func _on_teacher() -> void:
	_teacher_panel.show()
	_set_mode(&"setup" if LocalSettings.needs_pin_setup() else &"locked")


func _close_teacher_panel() -> void:
	_pin.text = ""
	_pin_confirm.text = ""
	_teacher_panel.hide()
	_teacher.grab_focus()


func _on_primary() -> void:
	match _mode:
		&"setup", &"change":
			_save_new_pin()
		&"locked":
			if DatabaseManager.is_pin_locked_out():
				_teacher_status.text = tr("TEACHER_LOCKED_OUT")
			elif _pin_ok():
				_set_mode(&"dashboard")
			else:
				_teacher_status.text = tr("TEACHER_LOCKED_OUT") if DatabaseManager.is_pin_locked_out() else tr("TEACHER_WRONG_PIN")
				_pin.text = ""


func _save_new_pin() -> void:
	var a: String = _pin.text.strip_edges()
	if not LocalSettings.is_valid_new_pin(a):
		_teacher_status.text = tr("TEACHER_PIN_INVALID")
		return
	if a != _pin_confirm.text.strip_edges():
		_teacher_status.text = tr("TEACHER_PIN_MISMATCH")
		_pin_confirm.text = ""
		return
	if not LocalSettings.set_teacher_pin(a):
		_teacher_status.text = tr("TEACHER_PIN_SAVE_FAILED")
		return
	DatabaseManager.reset_pin_lockout()
	_set_mode(&"dashboard")
	_pin.text = a
	_teacher_status.text = tr("TEACHER_PIN_SAVED")


func _fill_dashboard() -> void:
	for c: Node in _summary_grid.get_children():
		_summary_grid.remove_child(c)
		c.queue_free()
	var rows: Array[Dictionary] = DatabaseManager.get_class_summary()
	var attempts: int = 0
	for r: Dictionary in rows:
		attempts += int(r.get("attempts", 0))
	_summary_label.text = tr("TEACHER_SUMMARY") % [DatabaseManager.count_students(), attempts]
	if rows.is_empty():
		_summary_grid.columns = 1
		_summary_grid.add_child(UiKit.label(tr("TEACHER_NO_DATA"), 16))
		return
	_summary_grid.columns = 6
	for h: String in ["RECORDS_COL_STAGE", "TEACHER_COL_N", "TEACHER_COL_PRE", "TEACHER_COL_POST", "TEACHER_COL_GAIN", "TEACHER_COL_TIME"]:
		var l := UiKit.label(tr(h), 15)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.add_theme_color_override("font_color", UiKit.GOLD)
		_summary_grid.add_child(l)
	for r: Dictionary in rows:
		var secs: int = int(r.get("avg_seconds")) if r.get("avg_seconds") != null else 0
		for cell: String in [str(r.get("stage_index")), str(r.get("attempts")), _num(r.get("avg_pre")),
				_num(r.get("avg_post")), _signed(r.get("avg_gain")), "%d:%02d" % [secs / 60, secs % 60]]:
			var c := UiKit.label(cell, 16)
			c.autowrap_mode = TextServer.AUTOWRAP_OFF
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_summary_grid.add_child(c)


static func _num(v: Variant) -> String:
	return "–" if v == null else "%.1f" % float(v)


static func _signed(v: Variant) -> String:
	return "–" if v == null else "%+.1f" % float(v)


func _on_export() -> void:
	var path: String = DatabaseManager.export_eval_csv_for_teacher(_pin.text)
	if path == "":
		_teacher_status.text = tr("TEACHER_WRONG_PIN") if not _pin_ok() else tr("TEACHER_EXPORT_FAILED")
		return
	_teacher_status.text = tr("TEACHER_EXPORTED") + "\n" + path


func _on_copy_csv() -> void:
	var text: String = DatabaseManager.export_eval_csv_text_for_teacher(_pin.text)
	if text == "":
		_teacher_status.text = tr("TEACHER_EXPORT_FAILED")
		return
	DisplayServer.clipboard_set(text)
	_teacher_status.text = tr("TEACHER_COPIED")


func _on_open_folder() -> void:
	if not _pin_ok():
		_teacher_status.text = tr("TEACHER_WRONG_PIN")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))
	OS.shell_open(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))


func _on_change_pin() -> void:
	if not _pin_ok():
		_set_mode(&"locked")
		return
	_set_mode(&"change")


## Checked by DatabaseManager (which also enforces the brute-force lockout).
## An empty/missing PIN never unlocks.
func _pin_ok() -> bool:
	return DatabaseManager.verify_teacher_pin(_pin.text)
