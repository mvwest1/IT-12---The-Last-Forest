extends Control
## Main Menu: Play / Language / Teacher (PIN) / Quit.
## Results export lives ONLY inside the PIN-protected Teacher panel so
## children can't export class data. The teacher PIN is read from res://local_settings.cfg (not in GitHub).


@onready var _play: Button = %PlayButton
@onready var _language: Button = %LanguageButton
@onready var _teacher: Button = %TeacherButton
@onready var _quit: Button = %QuitButton
@onready var _teacher_panel: Control = %TeacherPanel
@onready var _pin: LineEdit = %PinEdit
@onready var _export: Button = %ExportButton
@onready var _open_folder: Button = %OpenFolderButton
@onready var _close_teacher: Button = %CloseTeacherButton
@onready var _teacher_status: Label = %TeacherStatus
@onready var _db_status: Label = %DbStatus


func _ready() -> void:
	_teacher_panel.hide()
	_play.pressed.connect(_on_play)
	_language.pressed.connect(_on_language)
	_teacher.pressed.connect(_on_teacher)
	_quit.pressed.connect(get_tree().quit)
	_export.pressed.connect(_on_export)
	_open_folder.pressed.connect(_on_open_folder)
	_close_teacher.pressed.connect(_close_teacher_panel)
	_pin.text_submitted.connect(func(_t: String) -> void: _on_export())
	_refresh_status_label()
	_refresh_language_label()
	_play.grab_focus()


func _on_play() -> void:
	if AppFlow.is_logged_in():
		AppFlow.go_stage_select()
	else:
		AppFlow.go_login()


func _on_language() -> void:
	TranslationServer.set_locale("fil" if TranslationServer.get_locale().begins_with("en") else "en")
	_refresh_language_label()
	_refresh_status_label()
	propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)


func _refresh_status_label() -> void:
	var db_text: String = tr("DB_OK") if DatabaseManager.is_available() else tr("DB_FALLBACK")
	_db_status.text = "v%s  •  %s" % [AppFlow.get_version(), db_text]


func _refresh_language_label() -> void:
	_language.text = "Language: English" if TranslationServer.get_locale().begins_with("en") else "Wika: Filipino"


func _on_teacher() -> void:
	_pin.text = ""
	_teacher_status.text = tr("TEACHER_ENTER_PIN")
	_teacher_panel.show()
	_pin.grab_focus()


func _close_teacher_panel() -> void:
	_pin.text = ""
	_teacher_panel.hide()
	_teacher.grab_focus()


func _on_export() -> void:
	var path: String = DatabaseManager.export_eval_csv_for_teacher(_pin.text)
	if path == "":
		_teacher_status.text = tr("TEACHER_WRONG_PIN") if not _pin_ok() else tr("TEACHER_EXPORT_FAILED")
		return
	_teacher_status.text = tr("TEACHER_EXPORTED") + "\n" + path


func _on_open_folder() -> void:
	if not _pin_ok():
		_teacher_status.text = tr("TEACHER_WRONG_PIN")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))
	OS.shell_open(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))


## Compares with the PIN in res://local_settings.cfg via DatabaseManager
## (which also enforces brute-force lockout). An empty/missing PIN never unlocks.
func _pin_ok() -> bool:
	return DatabaseManager.verify_teacher_pin(_pin.text)
