class_name StageController
extends Node
## One per stage scene. Owns: stage start, win condition, respawn,
## milestone facts, and moving to the next stage.
## It does NOT own counters (GameState) or UI (HUD) or visuals (RestorationController).

@export var data: StageData
@export var player: CharacterBody2D
@export var spawn_point: Marker2D

var _completed: bool = false


func _ready() -> void:
	GameState.start_stage(data)
	if spawn_point != null:
		GameState.checkpoint_position = spawn_point.global_position
	elif player != null:
		GameState.checkpoint_position = player.global_position
	EventBus.sapling_matured.connect(_on_sapling_matured)
	EventBus.arid_zone_hydrated.connect(_on_arid_zone_hydrated)
	EventBus.restoration_milestone_reached.connect(_on_milestone)
	EventBus.player_defeated.connect(_on_player_defeated)
	EventBus.stage_started.emit(data.stage_id)
	EventBus.objective_updated.emit(data.objective_key)
	for fact_id: StringName in data.intro_fact_ids:
		LearningDirector.request_fact(fact_id, LearningDirector.Priority.HIGH)


func _physics_process(_delta: float) -> void:
	if player != null and player.global_position.y > data.kill_y:
		GameState.damage_player(1)
		_respawn()


func _on_player_defeated() -> void:
	# Gentle failure: hearts refill, player returns to the last checkpoint,
	# every planted tree is KEPT. Learning progress is never taken away.
	GameState.restore_hearts()
	_respawn()


func _respawn() -> void:
	if player == null:
		return
	player.global_position = GameState.checkpoint_position
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()


func _on_milestone(index: int) -> void:
	if index < data.milestone_fact_ids.size() and data.milestone_fact_ids[index] != &"":
		LearningDirector.request_fact(data.milestone_fact_ids[index], LearningDirector.Priority.HIGH)


func _on_sapling_matured(_sapling: Node2D) -> void:
	_check_complete()


func _on_arid_zone_hydrated(_zone: Node2D) -> void:
	_check_complete()


func _check_complete() -> void:
	if _completed or GameState.trees_matured < data.tree_goal:
		return
	if data.require_all_arid_zones:
		for node: Node in get_tree().get_nodes_in_group(&"arid_zones"):
			if not (node as AridZone).is_hydrated():
				return
	_completed = true
	EventBus.stage_completed.emit(data.stage_id)
	if data.outro_fact_id != &"":
		if LearningDirector.request_fact(data.outro_fact_id, LearningDirector.Priority.HIGH, true):
			await EventBus.fact_card_closed
	if data.next_scene != "":
		get_tree().change_scene_to_file(data.next_scene)
