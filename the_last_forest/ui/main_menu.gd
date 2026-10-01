extends Control
## Main Menu: Play / Language / Teacher (PIN) / Quit.
## Results export lives ONLY inside the PIN-protected Teacher panel so
## children can't export class data. Change TEACHER_PIN before the pilot.

const TEACHER_PIN: String = "2468"

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
	_db_status.text = tr("DB_OK") if DatabaseManager.is_available() else tr("DB_FALLBACK")
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
	_db_status.text = tr("DB_OK") if DatabaseManager.is_available() else tr("DB_FALLBACK")
	propagate_notification(NOTIFICATION_TRANSLATION_CHANGED)


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
	if _pin.text != TEACHER_PIN:
		_teacher_status.text = tr("TEACHER_WRONG_PIN")
		return
	var path: String = DatabaseManager.export_eval_csv()
	_teacher_status.text = (tr("TEACHER_EXPORTED") + "\n" + path) if path != "" else tr("TEACHER_EXPORT_FAILED")


func _on_open_folder() -> void:
	if _pin.text != TEACHER_PIN:
		_teacher_status.text = tr("TEACHER_WRONG_PIN")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))
	OS.shell_open(ProjectSettings.globalize_path(DatabaseManager.EXPORT_DIR))
