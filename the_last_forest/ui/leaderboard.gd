extends Control
## Forest Rangers Leaderboard — read from the SQLite database.
## Score per learner = best Forest Points on each stage, added together
## (replaying a stage can only raise your score, never lower it).
## Shows nicknames or "Ranger #A9F2" codes only: never names or LRNs.

const TOP_N: int = 10
const TROPHY: Texture2D = preload("res://the_last_forest/art/ui_trophy.png")
const MEDALS: Array[Color] = [Color(1.0, 0.84, 0.3), Color(0.82, 0.85, 0.9), Color(0.85, 0.58, 0.35)]

var _grid: GridContainer
var _me_label: Label
var _tab_class: Button
var _tab_all: Button
var _class_only: bool = false


func _ready() -> void:
	UiKit.backdrop(self, 0.55)
	var v: VBoxContainer = UiKit.page(self)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var icon := TextureRect.new()
	icon.texture = TROPHY
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(icon)
	head.add_child(UiKit.banner(tr("LB_TITLE"), 24))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	head.add_child(tabs)
	_tab_class = UiKit.button(tr("LB_MY_CLASS"), _set_filter.bind(true), Vector2(120, 36))
	_tab_all = UiKit.button(tr("LB_EVERYONE"), _set_filter.bind(false), Vector2(120, 36))
	for t: Button in [_tab_class, _tab_all]:
		t.toggle_mode = true
		tabs.add_child(t)
	_tab_class.visible = AppFlow.is_logged_in() and AppFlow.grade_section != ""
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(_grid)
	_me_label = UiKit.label("", 17)
	_me_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_me_label.add_theme_color_override("font_color", UiKit.GOLD)
	v.add_child(_me_label)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	v.add_child(bottom)
	var back := UiKit.button(tr("UI_BACK"), AppFlow.go_main_menu, Vector2(130, 40))
	bottom.add_child(back)
	var foot := UiKit.label(tr("LB_PRIVACY") + "\n" + tr("LB_HOW"), 12, &"SubtleLabel")
	foot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(foot)
	_set_filter(_tab_class.visible)
	back.grab_focus()


func _set_filter(class_only: bool) -> void:
	_class_only = class_only
	_tab_class.set_pressed_no_signal(class_only)
	_tab_all.set_pressed_no_signal(not class_only)
	_refresh()


func _refresh() -> void:
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	if not DatabaseManager.is_available():
		_grid.columns = 1
		_grid.add_child(UiKit.label(tr("LB_NO_DB"), 18))
		_me_label.text = ""
		return
	var filter: String = AppFlow.grade_section if _class_only else ""
	var rows: Array[Dictionary] = DatabaseManager.get_leaderboard(TOP_N, filter)
	if rows.is_empty():
		_grid.columns = 1
		_grid.add_child(UiKit.label(tr("LB_EMPTY"), 18))
		_me_label.text = ""
		return
	_grid.columns = 5
	for h: String in ["#", tr("LB_RANGER"), tr("LB_CLASS"), tr("LB_STAGES"), tr("LB_POINTS")]:
		var l := UiKit.label(h, 15, &"SubtleLabel")
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		_grid.add_child(l)
	for r: Dictionary in rows:
		var mine: bool = int(r["student_id"]) == AppFlow.student_id
		var rank: int = int(r["rank"])
		var color: Color = UiKit.GOLD if mine else Color(0.96, 0.96, 0.93)
		var cells: Array[String] = [str(rank), str(r["display"]) + ("  ◀" if mine else ""),
				str(r["grade_section"]), "%d / 4" % int(r["stages_cleared"]), str(r["total_points"])]
		for i: int in cells.size():
			var l := UiKit.label(cells[i], 18)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.add_theme_color_override("font_color", MEDALS[rank - 1] if i == 0 and rank <= 3 else color)
			if i == 1:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if i == 4:
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_grid.add_child(l)
	_me_label.text = ""
	if AppFlow.is_logged_in():
		var me: Dictionary = DatabaseManager.get_leaderboard_entry(AppFlow.student_id, filter)
		if not me.is_empty():
			var total: int = DatabaseManager.get_leaderboard(100000, filter).size()
			_me_label.text = tr("LB_YOU") % [int(me["rank"]), total, int(me["total_points"])]
