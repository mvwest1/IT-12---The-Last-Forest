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
##   │  ├─ WaterBox (HBoxContainer)          %WaterBox
##   │  │  └─ WaterIcon + WaterLabel         %WaterLabel
##   ├─ TopRight (HBoxContainer)
##   │  └─ TreeIcon + TreeLabel  "3 / 5"     %TreeLabel
##   ├─ Objective (Label, top-center)        %ObjectiveLabel
##   ├─ Tip (PanelContainer > Label, bottom-center)   %TipPanel / %TipLabel
##   ├─ HoldBar (ProgressBar, above center)  %HoldBar
##   └─ FactCardPopup (instance, full rect)

const TIP_SECONDS: float = 4.0
const CLIMATE_TIP_PAUSE_OWNER: StringName = &"climate_tip"

@export var heart_full: Texture2D
@export var heart_empty: Texture2D
## Hide the water counter on stages without water.
@export var show_water: bool = false

var _tip_serial: int = 0
var _climate_tip_serial: int = 0

@onready var _hearts: HBoxContainer = %Hearts
@onready var _seeds: Label = %SeedLabel
@onready var _trees: Label = %TreeLabel
@onready var _water_box: Control = %WaterBox
@onready var _water: Label = %WaterLabel
@onready var _objective: Label = %ObjectiveLabel
@onready var _tip_panel: Control = %TipPanel
@onready var _tip: Label = %TipLabel
@onready var _hold_bar: ProgressBar = %HoldBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.seeds_changed.connect(_on_seeds_changed)
	EventBus.trees_planted_changed.connect(_on_trees_changed)
	EventBus.water_changed.connect(_on_water_changed)
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
	_water_box.visible = show_water
	# Initial pull.
	_on_seeds_changed(GameState.seeds)
	_on_trees_changed(GameState.trees_planted, GameState.tree_goal)
	_on_water_changed(GameState.water_carried, GameState.water_capacity)
	_on_health_changed(GameState.hearts, GameState.MAX_HEARTS)
	if GameState.current_stage != null:
		_on_objective_updated(GameState.current_stage.objective_key)


func _on_seeds_changed(total: int) -> void:
	_seeds.text = str(total)
	_pulse(_seeds)


func _on_trees_changed(total: int, goal: int) -> void:
	_trees.text = "%d / %d" % [total, goal]
	_pulse(_trees)


func _on_water_changed(carried: int, capacity: int) -> void:
	_water.text = "%d / %d" % [carried, capacity]


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
	var message: String = ""
	if tip_data is String:
		message = tr(tip_data)
	elif tip_data is Dictionary:
		if tip_data.has("text_key"):
			message = tr(str(tip_data["text_key"]))
		else:
			message = str(tip_data.get("text", ""))
	_tip.text = message
	_tip_panel.show()
	GameState.request_pause(CLIMATE_TIP_PAUSE_OWNER)
	await get_tree().create_timer(TIP_SECONDS, true).timeout
	if my_serial == _climate_tip_serial:
		_tip_panel.hide()
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
