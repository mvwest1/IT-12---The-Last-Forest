extends Control
## Student LRN login (teacher-assisted: most Grade 1–4 learners do not know
## their 12-digit LRN — the teacher types it from the class record).

@onready var _lrn: LineEdit = %LrnEdit
@onready var _name: LineEdit = %NameEdit
@onready var _grade: LineEdit = %GradeEdit
@onready var _error: Label = %ErrorLabel
@onready var _continue: Button = %ContinueButton
@onready var _back: Button = %BackButton


func _ready() -> void:
	_error.text = ""
	_continue.pressed.connect(_on_continue)
	_back.pressed.connect(AppFlow.go_main_menu)
	_lrn.text_changed.connect(_on_lrn_changed)
	_lrn.text_submitted.connect(func(_t: String) -> void: _name.grab_focus())
	_name.text_submitted.connect(func(_t: String) -> void: _grade.grab_focus())
	_grade.text_submitted.connect(func(_t: String) -> void: _on_continue())
	_lrn.grab_focus()


## Digits only, max 12.
func _on_lrn_changed(text: String) -> void:
	var digits: String = ""
	for c: String in text:
		if c >= "0" and c <= "9":
			digits += c
	digits = digits.left(12)
	if digits != text:
		_lrn.text = digits
		_lrn.caret_column = digits.length()


func _on_continue() -> void:
	var err: String = AppFlow.login(_lrn.text, _name.text, _grade.text)
	_error.text = tr(err) if err != "" else ""
