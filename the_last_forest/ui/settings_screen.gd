extends Control
## Settings: language, volume, accessibility, story replay, credits.
## Saved per device in user://settings.cfg (see Settings autoload).

var _lang_en: Button
var _lang_fil: Button


func _ready() -> void:
	UiKit.backdrop(self, 0.55)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	v.add_child(UiKit.banner(tr("SET_TITLE"), 26))
	# Language
	var lang_row := _row(v, tr("SET_LANGUAGE"))
	_lang_en = UiKit.button("English", _set_lang.bind("en"), Vector2(130, 40))
	_lang_fil = UiKit.button("Filipino", _set_lang.bind("fil"), Vector2(130, 40))
	for b: Button in [_lang_en, _lang_fil]:
		b.toggle_mode = true
		lang_row.add_child(b)
	_sync_lang()
	# Volumes
	_slider(_row(v, tr("SET_MUSIC")), Settings.music_volume, Settings.set_music_volume)
	_slider(_row(v, tr("SET_SFX")), Settings.sfx_volume, func(x: float) -> void:
		Settings.set_sfx_volume(x)
		Sfx.play(&"seed_pickup", 150))
	# Accessibility: tap-to-plant (same switch as in the pause menu)
	var tap := CheckButton.new()
	tap.text = tr("SET_TAP")
	tap.button_pressed = Settings.tap_to_plant
	tap.add_theme_font_size_override("font_size", 18)
	tap.toggled.connect(func(on: bool) -> void:
		Settings.tap_to_plant = on
		Settings.save())
	v.add_child(tap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiKit.button(tr("SET_STORY"), func() -> void:
		AppFlow.story_return = AppFlow.SETTINGS
		AppFlow.goto(AppFlow.STORY), Vector2(0, 42)))
	row.add_child(UiKit.button(tr("SET_CREDITS"), _show_credits, Vector2(0, 42)))
	var back := UiKit.button(tr("UI_BACK"), AppFlow.go_main_menu, Vector2(160, 44))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	back.grab_focus()


func _row(parent: Container, caption: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiKit.label(caption, 18)
	l.custom_minimum_size = Vector2(170, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	parent.add_child(h)
	return h


func _slider(row: HBoxContainer, value: float, on_change: Callable) -> void:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(300, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool) -> void: Settings.save())
	row.add_child(s)


func _set_lang(code: String) -> void:
	Settings.set_language(code)
	# Rebuild so every label is re-translated.
	AppFlow.goto(AppFlow.SETTINGS)


func _sync_lang() -> void:
	_lang_en.set_pressed_no_signal(Settings.language == "en")
	_lang_fil.set_pressed_no_signal(Settings.language == "fil")


func _show_credits() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var box: VBoxContainer = UiKit.modal(layer, Vector2(520, 0))
	box.add_child(UiKit.title(tr("SET_CREDITS"), 28))
	var body := UiKit.label(tr("CREDITS_TEXT").replace("\\n", "\n") % AppFlow.get_version(), 17)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(body)
	var close := UiKit.button(tr("UI_CLOSE"), layer.queue_free, Vector2(140, 42))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(close)
	close.grab_focus()


func handle_back() -> bool:
	AppFlow.go_main_menu()
	return true


## Keyboard/gamepad slider changes have no "drag ended": save on leaving.
func _exit_tree() -> void:
	Settings.save()
