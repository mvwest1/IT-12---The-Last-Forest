class_name GameHUD
extends Control
## Always-visible HUD. Listens to EventBus only; never polls gameplay nodes.
## Pulls initial values from GameState in _ready() because the stage's
## StageController may have emitted before the HUD existed (Godot readies
## the Level subtree before InterfaceLayer).
##
## Scene (game_hud.tscn) — full-rect Control inside the InterfaceLayer CanvasLayer:
##   GameHUD (Control, this script, mouse_filter = Ignore)
##   ├─ TopLeft (HBoxContainer)
##   │  ├─ Hearts (HBoxContainer)            %Hearts
##   │  ├─ SeedIcon (TextureRect) + SeedLabel (Label)   %SeedLabel
##   │  ├─ GuardBox (HBoxContainer)          %GuardBox   (Stage 2)
##   │  │  └─ GuardIcon + GuardLabel         %GuardLabel
##   │  ├─ WaterBox (HBoxContainer)          %WaterBox   (Stage 3)
##   │  │  └─ WaterIcon + WaterLabel "dry land left"  %WaterLabel
##   ├─ TopRight (HBoxContainer)
##   │  └─ TreeIcon + TreeLabel  "3 / 5"     %TreeLabel
##   ├─ Objective (Label, top-center)        %ObjectiveLabel
##   ├─ Tip (PanelContainer > Label, bottom-center)   %TipPanel / %TipLabel
##   ├─ HoldBar (ProgressBar, above center)  %HoldBar
##   ├─ FactCardPopup (instance, full rect)
##   ├─ QuizModal (full rect)
##   └─ PauseOverlay (full rect)

const TIP_SECONDS: float = 4.0
const CLIMATE_TIP_PAUSE_OWNER: StringName = &"climate_tip"

@export var heart_full: Texture2D
@export var heart_empty: Texture2D
## Counters only appear on the stages that use them.
@export var show_guards: bool = false
@export var show_water: bool = false

var _tip_serial: int = 0
var _climate_tip_serial: int = 0

@onready var _hearts: HBoxContainer = %Hearts
@onready var _seeds: Label = %SeedLabel
@onready var _trees: Label = %TreeLabel
@onready var _guard_box: Control = %GuardBox
@onready var _guards: Label = %GuardLabel
@onready var _water_box: Control = %WaterBox
@onready var _water: Label = %WaterLabel
@onready var _objective: Label = %ObjectiveLabel
@onready var _tip_panel: Control = %TipPanel
@onready var _tip: Label = %TipLabel
@onready var _hold_bar: ProgressBar = %HoldBar
@onready var _climate_modal: Control = %ClimateTipModal
@onready var _climate_title: Label = %ClimateTipTitle
@onready var _climate_label: Label = %ClimateTipLabel
@onready var _climate_dismiss: Button = %ClimateTipDismiss


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.seeds_changed.connect(_on_seeds_changed)
	EventBus.trees_matured_changed.connect(_on_trees_changed)
	EventBus.guards_changed.connect(_on_guards_changed)
	EventBus.water_delivered.connect(_on_water_delivered)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.objective_updated.connect(_on_objective_updated)
	EventBus.tip_requested.connect(show_tip)
	EventBus.climate_tip_triggered.connect(show_climate_tip)
	EventBus.interaction_started.connect(_on_interaction_started)
	EventBus.interaction_progress.connect(_on_interaction_progress)
	EventBus.interaction_cancelled.connect(_on_interaction_ended)
	EventBus.interaction_completed.connect(_on_interaction_ended)
	EventBus.interaction_denied.connect(_on_interaction_denied)
	_hold_bar.hide()
	_tip_panel.hide()
	_climate_modal.hide()
	_climate_dismiss.pressed.connect(_dismiss_climate_tip)
	_guard_box.visible = show_guards
	_water_box.visible = show_water
	# Initial pull.
	_on_seeds_changed(GameState.seeds)
	_on_trees_changed(GameState.trees_matured, GameState.tree_goal)
	_on_guards_changed(GameState.guards)
	_refresh_dry_land.call_deferred()
	_on_health_changed(GameState.hearts, GameState.MAX_HEARTS)
	if GameState.current_stage != null:
		_on_objective_updated(GameState.current_stage.objective_key)


func _on_seeds_changed(total: int) -> void:
	_seeds.text = str(total)
	_pulse(_seeds)


func _on_trees_changed(total: int, goal: int) -> void:
	_trees.text = "%d / %d" % [total, goal]
	_pulse(_trees)


func _on_guards_changed(total: int) -> void:
	_guards.text = str(total)
	_pulse(_guards)


func _on_water_delivered(_zone: Node2D, _amount: int) -> void:
	_refresh_dry_land()


## Shows the average hydration of all arid zones as a percentage.
func _refresh_dry_land() -> void:
	var zones: Array[Node] = get_tree().get_nodes_in_group(&"arid_zones")
	if zones.is_empty():
		_water.text = "-"
		return
	var total: float = 0.0
	for z: Node in zones:
		total += (z as AridZone).hydration_ratio()
	_water.text = "%d%%" % roundi(total / zones.size() * 100.0)


func _on_health_changed(current: int, maximum: int) -> void:
	for child: Node in _hearts.get_children():
		child.queue_free()
	for i: int in maximum:
		var icon := TextureRect.new()
		icon.texture = heart_full if i < current else heart_empty
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hearts.add_child(icon)


func _on_objective_updated(text_key: String) -> void:
	_objective.text = tr(text_key)


func show_tip(text_key: String) -> void:
	_tip_serial += 1
	var my_serial: int = _tip_serial
	_tip.text = tr(text_key)
	_tip_panel.show()
	await get_tree().create_timer(TIP_SECONDS).timeout
	if my_serial == _tip_serial:
		_tip_panel.hide()


## Pausing climate card. Accepts a translation key String or a Dictionary with
## `text_key` (preferred) or `text` fields. GameState owns pause arbitration.
func show_climate_tip(tip_data: Variant) -> void:
	_climate_tip_serial += 1
	var my_serial: int = _climate_tip_serial
	var title: String = tr("CLIMATE_TIP_TITLE")
	var message: String = ""
	if tip_data is String:
		message = tr(tip_data)
	elif tip_data is Dictionary:
		title = str(tip_data.get("title", title))
		if tip_data.has("text_key"):
			message = tr(str(tip_data["text_key"]))
		else:
			message = str(tip_data.get("text", ""))
	_climate_title.text = title
	_climate_label.text = message
	_climate_modal.show()
	GameState.request_pause(CLIMATE_TIP_PAUSE_OWNER)
	await get_tree().create_timer(TIP_SECONDS, true).timeout
	if my_serial == _climate_tip_serial:
		_climate_modal.hide()
		GameState.release_pause(CLIMATE_TIP_PAUSE_OWNER)


func _dismiss_climate_tip() -> void:
	_climate_tip_serial += 1
	_climate_modal.hide()
	GameState.release_pause(CLIMATE_TIP_PAUSE_OWNER)


func _on_interaction_started(_target: Node2D) -> void:
	_hold_bar.value = 0.0
	_hold_bar.show()


func _on_interaction_progress(_target: Node2D, ratio: float) -> void:
	_hold_bar.value = ratio * 100.0


func _on_interaction_ended(_target: Node2D) -> void:
	_hold_bar.hide()


func _on_interaction_denied(_target: Node2D, reason: StringName) -> void:
	show_tip("DENY_" + String(reason).to_upper())


func _pulse(item: Control) -> void:
	item.pivot_offset = item.size / 2.0
	var tween := create_tween()
	tween.tween_property(item, ^"scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(item, ^"scale", Vector2.ONE, 0.12)
