extends Control
## The story of Sierra Verde, shown once before the first game on a device
## (and any time from Settings). Picture first, short sentences, bilingual.

const PAGES: Array[Dictionary] = [
	{"text": "STORY_1", "image": "res://the_last_forest/art/fact_forest_home.png"},
	{"text": "STORY_2", "image": "res://the_last_forest/art/fact_burning_releases_co2.png"},
	{"text": "STORY_3", "image": "res://the_last_forest/art/ranger_portrait.png"},
	{"text": "STORY_4", "image": "res://the_last_forest/art/fact_trees_store_carbon.png"},
]

var _index: int = 0
var _image: TextureRect
var _text: Label
var _sub: Label
var _next: Button
var _dots: Label


func _ready() -> void:
	UiKit.backdrop(self, 0.6)
	var v: VBoxContainer = UiKit.page(self, 22)
	v.add_child(UiKit.title(tr("STORY_TITLE"), 30))
	_image = TextureRect.new()
	_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_image.custom_minimum_size = Vector2(0, 200)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(_image)
	var paper := UiKit.parchment_panel()
	v.add_child(paper)
	var pv := VBoxContainer.new()
	paper.add_child(pv)
	_text = UiKit.ink("", 20, true)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_text)
	_sub = UiKit.ink("", 15)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	row.add_child(UiKit.button(tr("UI_SKIP"), _finish, Vector2(140, 44)))
	_dots = UiKit.label("", 22)
	_dots.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_dots)
	_next = UiKit.button(tr("UI_NEXT"), _advance, Vector2(180, 44), true)
	row.add_child(_next)
	_show()
	_next.grab_focus()


func _show() -> void:
	var p: Dictionary = PAGES[_index]
	_image.texture = load(p["image"]) as Texture2D
	var key: String = p["text"]
	_text.text = tr(key)
	# The other language underneath, so both readers follow along.
	var other: String = "fil" if TranslationServer.get_locale().begins_with("en") else "en"
	_sub.text = UiKit.tr_in(key, other)
	var d: String = ""
	for i: int in PAGES.size():
		d += "● " if i == _index else "○ "
	_dots.text = d.strip_edges()
	_next.text = tr("UI_START") if _index == PAGES.size() - 1 else tr("UI_NEXT")
	_image.modulate.a = 0.0
	create_tween().tween_property(_image, ^"modulate:a", 1.0, 0.35)


func _advance() -> void:
	if _index < PAGES.size() - 1:
		_index += 1
		_show()
	else:
		_finish()


func _finish() -> void:
	var first_time: bool = not Settings.story_seen
	Settings.mark_story_seen()
	if first_time:
		if AppFlow.is_logged_in():
			AppFlow.go_stage_select()
		else:
			AppFlow.go_login()
	else:
		AppFlow.go_main_menu()


func handle_back() -> bool:
	_finish()
	return true
