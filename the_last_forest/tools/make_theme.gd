extends SceneTree
## Regenerates the shared UI theme + world label style.
## Run: godot --headless --path . -s res://the_last_forest/tools/make_theme.gd
## Edit the colours below and re-run to restyle every screen at once.

const OUT_THEME := "res://the_last_forest/ui/ui_theme.tres"
const OUT_WORLD_LABEL := "res://the_last_forest/ui/world_label.tres"
const HEADER_FONT := "res://gui/kenney_mini_square.ttf"
const UI_DIR := "res://the_last_forest/art/ui_kenney/"

# Forest palette
const LEAF := Color8(63, 128, 58)
const LEAF_HOVER := Color8(82, 158, 70)
const LEAF_PRESSED := Color8(46, 100, 44)
const LEAF_DARK := Color8(30, 66, 32)
const LEAF_LIGHT := Color8(150, 214, 100)
const CARD := Color8(26, 52, 34, 238)
const CARD_BORDER := Color8(126, 196, 82)
const GOLD := Color8(246, 201, 69)
const CREAM := Color8(248, 244, 228)
const TEXT := Color8(246, 246, 236)
const TEXT_DIM := Color8(236, 222, 190)
const DISABLED := Color8(78, 80, 72)


func _initialize() -> void:
	var t := Theme.new()
	t.default_font_size = 18

	# ---------------- Panels / cards
	# Kenney "UI Pack - Pixel Adventure" (CC0): wooden panel with steel corners.
	var card := _tex("panel_wood", 10, 22, 16)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)
	# HUD pill: translucent dark, used by theme_type_variation = "HudPanel"
	var pill := _tex("panel_hud", 5, 10, 4)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", pill)

	# ---------------- Buttons (3D leaf buttons, gold focus ring for keyboard/gamepad)
	t.set_stylebox("normal", "Button", _tex("button_normal", 5, 18, 8))
	t.set_stylebox("hover", "Button", _tex("button_hover", 5, 18, 8))
	t.set_stylebox("pressed", "Button", _tex("button_pressed", 5, 18, 9))
	t.set_stylebox("disabled", "Button", _tex("button_disabled", 5, 18, 8))
	var focus := _tex("focus_frame", 4, 0, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color8(170, 170, 160))
	t.set_color("font_outline_color", "Button", Color8(60, 34, 14))
	t.set_constant("outline_size", "Button", 2)
	t.set_font_size("font_size", "Button", 20)
	# Big menu buttons
	t.set_type_variation("BigButton", "Button")
	t.set_font_size("font_size", "BigButton", 24)

	# ---------------- Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	var header_font: FontFile = load(HEADER_FONT)
	t.set_type_variation("HeaderLabel", "Label")
	if header_font != null:
		t.set_font("font", "HeaderLabel", header_font)
	t.set_font_size("font_size", "HeaderLabel", 40)
	t.set_color("font_color", "HeaderLabel", GOLD)
	t.set_color("font_outline_color", "HeaderLabel", Color8(40, 28, 18))
	t.set_constant("outline_size", "HeaderLabel", 10)
	t.set_type_variation("SubtleLabel", "Label")
	t.set_color("font_color", "SubtleLabel", TEXT_DIM)
	t.set_font_size("font_size", "SubtleLabel", 14)
	t.set_type_variation("HudLabel", "Label")
	t.set_font_size("font_size", "HudLabel", 20)
	t.set_color("font_outline_color", "HudLabel", Color(0, 0, 0))
	t.set_constant("outline_size", "HudLabel", 5)

	# ---------------- Text input (light field, dark text: readable for kids)
	var field := _tex("field", 5, 12, 8)
	var field_focus := _tex("focus_frame", 4, 12, 8)
	field_focus.draw_center = false
	field_focus.set_expand_margin_all(2)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", Color8(36, 36, 32))
	t.set_color("font_placeholder_color", "LineEdit", Color8(130, 130, 120))
	t.set_color("caret_color", "LineEdit", Color8(36, 36, 32))
	t.set_font_size("font_size", "LineEdit", 20)

	# ---------------- Progress bars (hold-to-plant, meters)
	var bg := _tex("bar_back", 5, 0, 0)
	var fill := _tex("bar_fill", 4, 0, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)

	# ---------------- Sliders (settings volume)
	t.set_stylebox("slider", "HSlider", _tex("bar_back", 5, 0, 6))
	t.set_stylebox("grabber_area", "HSlider", _tex("bar_fill", 4, 0, 6))
	t.set_stylebox("grabber_area_highlight", "HSlider", _tex("bar_fill", 4, 0, 6))
	var grab: Texture2D = load(UI_DIR + "slider_grabber.png")
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab)

	# ---------------- CheckButton text
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_font_size("font_size", "CheckButton", 16)

	var err := ResourceSaver.save(t, OUT_THEME)
	print("theme -> ", OUT_THEME, " err=", err)

	var ls := LabelSettings.new()
	ls.font_size = 14
	ls.font_color = Color.WHITE
	ls.outline_size = 6
	ls.outline_color = Color8(20, 30, 20)
	ls.shadow_color = Color(0, 0, 0, 0.4)
	print("world label -> ", OUT_WORLD_LABEL, " err=", ResourceSaver.save(ls, OUT_WORLD_LABEL))
	quit()


func _box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


func _button(bg: Color, edge: Color, pressed: bool = false) -> StyleBoxFlat:
	var s := _box(bg, edge, 2, 12)
	# chunky 3D bottom edge; pressed buttons sink down
	s.border_width_bottom = 2 if pressed else 6
	s.border_width_top = 4 if pressed else 2
	s.content_margin_left = 18; s.content_margin_right = 18
	s.content_margin_top = 8; s.content_margin_bottom = 8
	return s


## Nine-slice box from a Kenney UI tile (pixel art stays crisp: the project
## uses nearest filtering). margin = border size in texture pixels.
func _tex(name: String, margin: int, pad_x: int, pad_y: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI_DIR + name + ".png")
	s.texture_margin_left = margin; s.texture_margin_right = margin
	s.texture_margin_top = margin; s.texture_margin_bottom = margin
	s.content_margin_left = pad_x; s.content_margin_right = pad_x
	s.content_margin_top = pad_y; s.content_margin_bottom = pad_y
	return s
