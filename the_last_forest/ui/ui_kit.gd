class_name UiKit
extends RefCounted
## Small helpers so every menu screen looks the same (built from
## ui_theme.tres) without hand-placing nodes in each scene.

const THEME: Theme = preload("res://the_last_forest/ui/ui_theme.tres")
const MENU_BG: Texture2D = preload("res://the_last_forest/art/menu_bg.png")
const PARCHMENT: Texture2D = preload("res://the_last_forest/art/parchment.png")
const GOLD := Color(0.965, 0.788, 0.271)
const INK := Color(0.23, 0.16, 0.09)
const TRANSLATION_FILES: Dictionary = {
	"en": ["res://the_last_forest/data/translations/ui.en.translation",
			"res://the_last_forest/data/translations/facts.en.translation"],
	"fil": ["res://the_last_forest/data/translations/ui.fil.translation",
			"res://the_last_forest/data/translations/facts.fil.translation"],
}

static var _tr_cache: Dictionary = {}


## Full-screen root setup: theme + forest background + dark shade.
static func backdrop(root: Control, shade: float = 0.35) -> void:
	root.theme = THEME
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	bg.texture = MENU_BG
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.03, shade)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)


## Margin + VBox filling the screen; returns the VBox.
static func page(root: Control, margin: int = 18) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	m.add_child(v)
	return v


## Centered dimmed modal with a panel; returns the panel's VBox.
static func modal(root: Control, min_size: Vector2 = Vector2(520, 0)) -> VBoxContainer:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = min_size
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	return v


static func title(text: String, size: int = 34) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"HeaderLabel"
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func label(text: String, size: int = 18, variation: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if variation != &"":
		l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, on_press: Callable, min_size: Vector2 = Vector2(0, 46), big: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	if big:
		b.theme_type_variation = &"BigButton"
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


## Parchment card (nine-slice) used for bilingual fact pages.
static func parchment_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", parchment_style())
	return p


static func parchment_style() -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = PARCHMENT
	sb.texture_margin_left = 18
	sb.texture_margin_right = 18
	sb.texture_margin_top = 18
	sb.texture_margin_bottom = 18
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb


## Ink-colored label for text drawn on parchment.
static func ink(text: String, size: int = 16, bold: bool = false) -> Label:
	var l := label(text, size)
	l.add_theme_color_override("font_color", INK if not bold else Color(0.16, 0.33, 0.12))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	return l


## A translation in a SPECIFIC language, whatever the current locale is
## (for side-by-side English / Filipino fact cards).
static func tr_in(key: String, locale: String) -> String:
	if not _tr_cache.has(locale):
		var list: Array[Translation] = []
		for path: String in TRANSLATION_FILES.get(locale, []):
			var t := load(path) as Translation
			if t != null:
				list.append(t)
		_tr_cache[locale] = list
	for t: Translation in _tr_cache[locale]:
		var msg: String = String(t.get_message(StringName(key)))
		if msg != "":
			return msg
	return key


static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
