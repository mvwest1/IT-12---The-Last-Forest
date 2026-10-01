class_name StageController
extends Node
## One per stage scene. Owns the stage loop:
##
##   _ready -> GameState.start_stage
##   PRE-QUIZ (paused)  -> DB: quiz_results.pre_score
##   intro fact card    -> PLAY (timer runs only while unpaused)
##   goal met           -> outro fact -> POST-QUIZ -> AppFlow.finish_stage()
##                         (DB: quiz_results.post_score + session_records row)
##                      -> Stage Clear screen
##
## It does NOT own counters (GameState), UI (HUD) or visuals (RestorationController).

@export var data: StageData
## Pre/post test for this stage (same set both times).
@export var quiz: QuizSet
@export var player: CharacterBody2D
@export var spawn_point: Marker2D
@export var exit_gate: Node2D

var _completed: bool = false
var _active: bool = false
## Seconds of actual play (excludes pause menu, fact cards and quizzes,
## because _process stops while the tree is paused).
var _elapsed: float = 0.0
var _pre_score: int = -1


func _ready() -> void:
	# Fallbacks: scenes saved without node_paths leave these exports empty.
	if player == null:
		player = get_node_or_null(^"../Player") as CharacterBody2D
	if spawn_point == null:
		spawn_point = get_node_or_null(^"../SpawnPoint") as Marker2D
	if exit_gate == null:
		exit_gate = get_node_or_null(^"../ExitGate") as Node2D
	GameState.start_stage(data)
	_fit_camera_to_level()
	if AppFlow.current_stage_index == 0:
		AppFlow.current_stage_index = data.stage_index  # launched directly (F6)
	if spawn_point != null:
		GameState.checkpoint_position = spawn_point.global_position
	elif player != null:
		GameState.checkpoint_position = player.global_position
	EventBus.sapling_matured.connect(_on_sapling_matured)
	EventBus.tree_planted.connect(_on_tree_planted)
	EventBus.sapling_damaged.connect(_on_tree_state_changed.unbind(1))
	EventBus.sapling_wilted.connect(_on_tree_state_changed)
	EventBus.sapling_revived.connect(_on_tree_state_changed)
	EventBus.arid_zone_hydrated.connect(_on_arid_zone_hydrated)
	EventBus.restoration_milestone_reached.connect(_on_milestone)
	EventBus.player_defeated.connect(_on_player_defeated)
	_register_existing_saplings.call_deferred()
	_begin.call_deferred()


func _begin() -> void:
	# One frame so the HUD, FactCardPopup and QuizModal have registered.
	await get_tree().process_frame
	_pre_score = await LearningDirector.run_quiz(quiz, &"pre")
	AppFlow.record_pre_quiz(data.stage_index, _pre_score)
	EventBus.stage_started.emit(data.stage_id)
	EventBus.objective_updated.emit(data.objective_key)
	for fact_id: StringName in data.intro_fact_ids:
		LearningDirector.request_fact(fact_id, LearningDirector.Priority.HIGH)
	_active = true
	_refresh_exit_gate()


func _process(delta: float) -> void:
	if _active and not _completed:
		_elapsed += delta


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
	_refresh_exit_gate()


func _on_arid_zone_hydrated(_zone: Node2D) -> void:
	_refresh_exit_gate()


func _on_tree_planted(_zone: Node2D, _sapling: Node2D) -> void:
	_refresh_exit_gate()


func _on_tree_state_changed(_sapling: Node2D) -> void:
	_refresh_exit_gate()


func _register_existing_saplings() -> void:
	await get_tree().process_frame
	var existing: int = get_tree().get_nodes_in_group(&"saplings").size()
	if existing > 0:
		GameState.register_preplanted_saplings(existing)
	_refresh_exit_gate()


func can_clear_stage() -> bool:
	if not _active or _completed or not GameState.can_clear_stage():
		return false
	if data.require_all_arid_zones:
		for node: Node in get_tree().get_nodes_in_group(&"arid_zones"):
			if not (node as AridZone).is_hydrated():
				return false
	return true


func _refresh_exit_gate() -> void:
	if is_instance_valid(exit_gate) and exit_gate.has_method("refresh_state"):
		exit_gate.call("refresh_state", can_clear_stage())


func request_stage_clear() -> void:
	if not can_clear_stage():
		return
	_completed = true
	_active = false
	EventBus.stage_completed.emit(data.stage_id)
	EventBus.stage_cleared.emit()
	if data.outro_fact_id != &"":
		LearningDirector.request_fact(data.outro_fact_id, LearningDirector.Priority.HIGH, true)
	# Let the final milestone fact / outro card finish before the post-test.
	# Safety: never wait more than 20 s (e.g. a card that can't be shown).
	var waited_ms: int = 0
	while not LearningDirector.is_idle() and waited_ms < 20000:
		await get_tree().process_frame
		waited_ms += int(get_process_delta_time() * 1000.0) + 1
	LearningDirector.clear_queue()
	var post_score: int = await LearningDirector.run_quiz(quiz, &"post")
	AppFlow.finish_stage({
		"stage_index": data.stage_index,
		"seeds_collected": GameState.seeds_collected,
		"trees_matured": GameState.trees_matured,
		"duration": _elapsed,
		"tips_viewed": GameState.tips_viewed,
		"pre_score": _pre_score,
		"post_score": post_score,
		"quiz_total": quiz.questions.size() if quiz != null else 0,
	})


## Clamps the player's camera to the level's tiles, so each stage can have
## its own width/height without editing the player scene.
func _fit_camera_to_level() -> void:
	var tiles := get_node_or_null(^"../TileMapLayer") as TileMapLayer
	if tiles == null or player == null or tiles.tile_set == null:
		return
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam == null:
		return
	var used: Rect2i = tiles.get_used_rect()
	var size: Vector2i = tiles.tile_set.tile_size
	cam.limit_left = used.position.x * size.x
	cam.limit_right = used.end.x * size.x
	cam.limit_top = used.position.y * size.y - size.y * 2  # a little sky above the walls
	cam.limit_bottom = used.end.y * size.y
	cam.reset_smoothing()
