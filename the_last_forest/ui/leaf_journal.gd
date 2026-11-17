extends Control
## Leaf Journal (Elder Narra's field notes) — every climate fact the learner
## has unlocked, saved in the database (journal_entries) so it is still
## there next week. Each page is BILINGUAL: English and Filipino side by
## side on a parchment card, whatever the current language is.

var _facts: Array[ClimateFact] = []
var _unlocked: Array[StringName] = []
var _grid: GridContainer
var _page_layer: Control


func _ready() -> void:
	UiKit.backdrop(self, 0.55)
	_facts = LearningDirector.get_all_facts()
	_unlocked = AppFlow.journal_fact_ids()
	var v: VBoxContainer = UiKit.page(self)
	v.add_child(UiKit.title(tr("JOURNAL_TITLE"), 32))
	var found: int = 0
	for f: ClimateFact in _facts:
		if f.id in _unlocked:
			found += 1
	var sub := UiKit.label(tr("JOURNAL_NOTES") + "  •  " + tr("JOURNAL_FOUND") % [found, _facts.size()], 16, &"SubtleLabel")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(_grid)
	var first: Button = null
	for f: ClimateFact in _facts:
		var b := _tile(f)
		_grid.add_child(b)
		if first == null:
			first = b
	var back := UiKit.button(tr("UI_BACK"), AppFlow.go_main_menu, Vector2(160, 42))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	(first if first != null else back).grab_focus()


func _tile(f: ClimateFact) -> Button:
	var open: bool = f.id in _unlocked
	var b := Button.new()
	b.custom_minimum_size = Vector2(176, 130)
	b.icon = f.image if open else null
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.text = tr(f.title_key) if open else "?"
	b.add_theme_font_size_override("font_size", 14 if open else 40)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not open
	b.tooltip_text = "" if open else tr("JOURNAL_LOCKED")
	if open:
		b.pressed.connect(_open_page.bind(f))
	return b


## Bilingual parchment page.
func _open_page(f: ClimateFact) -> void:
	_page_layer = Control.new()
	_page_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_layer.add_child(center)
	var paper := UiKit.parchment_panel()
	paper.custom_minimum_size = Vector2(700, 0)
	center.add_child(paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	paper.add_child(v)
	var img := TextureRect.new()
	img.texture = f.image
	img.custom_minimum_size = Vector2(0, 150)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(img)
	v.add_child(bilingual_block(f))
	var stage := UiKit.ink(tr("JOURNAL_STAGE") % f.stage, 13)
	stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stage)
	var close := UiKit.button(tr("UI_CLOSE"), _close_page, Vector2(140, 40))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	close.grab_focus()


func _close_page() -> void:
	if is_instance_valid(_page_layer):
		_page_layer.queue_free()
	_page_layer = null


## English | Filipino columns, reused by the in-game fact card.
static func bilingual_block(f: ClimateFact) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	for loc: String in ["en", "fil"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UiKit.ink("ENGLISH" if loc == "en" else "FILIPINO", 11))
		col.add_child(UiKit.ink(UiKit.tr_in(f.title_key, loc), 19, true))
		col.add_child(UiKit.ink(UiKit.tr_in(f.body_key, loc), 15))
		row.add_child(col)
		if loc == "en":
			var sep := VSeparator.new()
			row.add_child(sep)
	return row


func handle_back() -> bool:
	if _page_layer != null:
		_close_page()
	else:
		AppFlow.go_main_menu()
	return true
