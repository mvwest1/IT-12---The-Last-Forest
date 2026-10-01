extends SceneTree
## Regenerates the shared UI theme + world label style.
## Run: godot --headless --path . -s res://the_last_forest/tools/make_theme.gd
## Edit the colours below and re-run to restyle every screen at once.

const OUT_THEME := "res://the_last_forest/ui/ui_theme.tres"
const OUT_WORLD_LABEL := "res://the_last_forest/ui/world_label.tres"
const HEADER_FONT := "res://gui/kenney_mini_square.ttf"

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
const TEXT_DIM := Color8(190, 200, 180)
const DISABLED := Color8(78, 80, 72)


func _initialize() -> void:
	var t := Theme.new()
	t.default_font_size = 18

	# ---------------- Panels / cards
	var card := _box(CARD, CARD_BORDER, 3, 14)
	card.shadow_color = Color(0, 0, 0, 0.35); card.shadow_size = 8; card.shadow_offset = Vector2(0, 4)
	card.content_margin_left = 22; card.content_margin_right = 22
	card.content_margin_top = 16; card.content_margin_bottom = 16
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card)
	# HUD pill: translucent dark, used by theme_type_variation = "HudPanel"
	var pill := _box(Color(0.06, 0.12, 0.08, 0.72), Color(1, 1, 1, 0.18), 2, 12)
	pill.content_margin_left = 10; pill.content_margin_right = 10
	pill.content_margin_top = 4; pill.content_margin_bottom = 4
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", pill)

	# ---------------- Buttons (3D leaf buttons, gold focus ring for keyboard/gamepad)
	t.set_stylebox("normal", "Button", _button(LEAF, LEAF_DARK))
	t.set_stylebox("hover", "Button", _button(LEAF_HOVER, LEAF_DARK))
	t.set_stylebox("pressed", "Button", _button(LEAF_PRESSED, LEAF_DARK, true))
	t.set_stylebox("disabled", "Button", _button(DISABLED, Color8(50, 52, 46)))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(3); focus.border_color = GOLD
	focus.set_corner_radius_all(12); focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color8(170, 170, 160))
	t.set_color("font_outline_color", "Button", Color8(20, 40, 20))
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
	var field := _box(CREAM, CARD_BORDER, 2, 8)
	field.content_margin_left = 12; field.content_margin_right = 12
	field.content_margin_top = 8; field.content_margin_bottom = 8
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = GOLD; field_focus.set_border_width_all(3)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", Color8(36, 36, 32))
	t.set_color("font_placeholder_color", "LineEdit", Color8(130, 130, 120))
	t.set_color("caret_color", "LineEdit", Color8(36, 36, 32))
	t.set_font_size("font_size", "LineEdit", 20)

	# ---------------- Progress bars (hold-to-plant, meters)
	var bg := _box(Color(0.05, 0.1, 0.06, 0.8), Color(1, 1, 1, 0.25), 2, 7)
	var fill := _box(LEAF_LIGHT, LEAF_LIGHT, 0, 7)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)

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
