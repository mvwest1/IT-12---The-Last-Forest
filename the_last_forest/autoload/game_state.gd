extends Node
## GameState (Autoload) — the single source of truth for run data.
##
## Owns: seeds, tree guards, trees planted/matured, 3 hearts, milestones,
## per-stage research stats, and PAUSE arbitration.
## Never write get_tree().paused anywhere else — call request_pause(owner) /
## release_pause(owner) so the pause menu, fact cards and quizzes can never
## unpause each other.
##
## Replaces the demo's "player is invincible": hearts live here, damage comes
## from Hazard areas and the stage kill plane, never from the player script.

const MAX_HEARTS: int = 3
const INVULNERABLE_MSEC: int = 1200
## Fractions of the stage tree goal that trigger visual/learning milestones.
const MILESTONES: Array[float] = [0.25, 0.5, 0.75, 1.0]

var seeds: int = 0
var guards: int = 0
var trees_planted: int = 0
## Trees that survived to full size. Restoration is driven by THIS.
var trees_matured: int = 0
var tree_goal: int = 1
var hearts: int = MAX_HEARTS
var unlocked_facts: Array[StringName] = []
var checkpoint_position: Vector2 = Vector2.ZERO
## Session-wide progression for guest mode and stage-select validation.
var highest_completed_stage: int = 0
var current_stage: StageData = null

# ---- Research stats for the current stage (written to SQLite on clear).
## Seeds picked up during the stage (starting seeds are NOT counted).
var seeds_collected: int = 0
## Learning cards + climate tips shown during the stage.
var tips_viewed: int = 0

var _base_restoration: float = 0.0
var _milestone_index: int = -1
var _invulnerable_until: int = 0
var _pause_owners: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.tree_planted.connect(_on_tree_planted)
	EventBus.sapling_matured.connect(_on_sapling_matured)
	EventBus.fact_card_opened.connect(_on_learning_shown.unbind(1))
	EventBus.climate_tip_triggered.connect(_on_learning_shown.unbind(1))
	EventBus.tip_requested.connect(_on_tip_requested)


# ------------------------------------------------------------------ Stage
func start_stage(data: StageData) -> void:
	current_stage = data
	seeds = data.starting_seeds
	guards = data.starting_guards
	trees_planted = 0
	trees_matured = 0
	tree_goal = maxi(1, data.tree_goal)
	_base_restoration = data.base_restoration
	hearts = MAX_HEARTS
	seeds_collected = 0
	tips_viewed = 0
	_milestone_index = -1
	clear_pauses()
	_broadcast_all()


## Count saplings placed as part of a stage layout (for example, Stage 2's
## protected canopy saplings) in the same requirement as player-planted trees.
func register_preplanted_saplings(amount: int) -> void:
	trees_planted += maxi(0, amount)
	EventBus.trees_planted_changed.emit(trees_planted, tree_goal)


## Exit gates call this at the moment the player reaches them. A tree is only
## complete once it is mature, alive, and at full health.
func can_clear_stage() -> bool:
	if trees_planted < tree_goal or trees_matured != tree_goal:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"saplings"):
		if not is_instance_valid(node):
			continue
		if node is Sapling:
			var sapling: Sapling = node
			if sapling.wilted or sapling.stage != Sapling.Stage.TREE or sapling.health < sapling.max_health:
				return false
	return true


func _broadcast_all() -> void:
	EventBus.seeds_changed.emit(seeds)
	EventBus.guards_changed.emit(guards)
	EventBus.trees_planted_changed.emit(trees_planted, tree_goal)
	EventBus.trees_matured_changed.emit(trees_matured, tree_goal)
	EventBus.player_health_changed.emit(hearts, MAX_HEARTS)
	EventBus.restoration_changed.emit(restoration_ratio())


## Stage-local progress 0..1 (matured / goal).
func goal_progress() -> float:
	return clampf(float(trees_matured) / float(tree_goal), 0.0, 1.0)


## Visual restoration 0..1 used by shaders (starts at the stage's base value).
func restoration_ratio() -> float:
	return lerpf(_base_restoration, 1.0, goal_progress())


func milestone_index() -> int:
	return _milestone_index


# ------------------------------------------------------------------ Seeds
## Called by SeedPickup only (counts toward seeds_collected).
func add_seeds(amount: int) -> void:
	seeds += amount
	seeds_collected += amount
	EventBus.seeds_changed.emit(seeds)


func try_spend_seed() -> bool:
	if seeds <= 0:
		return false
	seeds -= 1
	EventBus.seeds_changed.emit(seeds)
	return true


# ------------------------------------------------------------------ Tree guards (Stage 2)
func add_guards(amount: int) -> void:
	guards += amount
	EventBus.guards_changed.emit(guards)


func try_spend_guard() -> bool:
	if guards <= 0:
		return false
	guards -= 1
	EventBus.guards_changed.emit(guards)
	return true


# ------------------------------------------------------------------ Health (3 hearts)
func damage_player(amount: int = 1) -> void:
	var now: int = Time.get_ticks_msec()
	if now < _invulnerable_until or hearts <= 0:
		return
	_invulnerable_until = now + INVULNERABLE_MSEC
	hearts = maxi(0, hearts - amount)
	EventBus.player_damaged.emit(amount)
	EventBus.player_health_changed.emit(hearts, MAX_HEARTS)
	if hearts == 0:
		EventBus.player_defeated.emit()


func restore_hearts() -> void:
	hearts = MAX_HEARTS
	EventBus.player_health_changed.emit(hearts, MAX_HEARTS)


func is_invulnerable() -> bool:
	return Time.get_ticks_msec() < _invulnerable_until


func record_stage_cleared(stage_index: int) -> void:
	highest_completed_stage = maxi(highest_completed_stage, stage_index)


# ------------------------------------------------------------------ Facts
## Returns true the first time a fact is unlocked.
func unlock_fact(fact_id: StringName) -> bool:
	if fact_id in unlocked_facts:
		return false
	unlocked_facts.append(fact_id)
	EventBus.climate_fact_unlocked.emit(fact_id)
	return true


# ------------------------------------------------------------------ Pause ownership
func request_pause(owner_id: StringName) -> void:
	_pause_owners[owner_id] = true
	get_tree().paused = true


func release_pause(owner_id: StringName) -> void:
	_pause_owners.erase(owner_id)
	get_tree().paused = not _pause_owners.is_empty()


func is_paused_by(owner_id: StringName) -> bool:
	return _pause_owners.has(owner_id)


## Used on scene changes so a stale owner can never freeze the next scene.
func clear_pauses() -> void:
	_pause_owners.clear()
	get_tree().paused = false


# ------------------------------------------------------------------ Listeners
func _on_tree_planted(_zone: Node2D, _sapling: Node2D) -> void:
	trees_planted += 1
	EventBus.trees_planted_changed.emit(trees_planted, tree_goal)


func _on_sapling_matured(_sapling: Node2D) -> void:
	trees_matured += 1
	EventBus.trees_matured_changed.emit(trees_matured, tree_goal)
	EventBus.restoration_changed.emit(restoration_ratio())
	var progress: float = goal_progress()
	while _milestone_index + 1 < MILESTONES.size() and progress >= MILESTONES[_milestone_index + 1] - 0.0001:
		_milestone_index += 1
		EventBus.restoration_milestone_reached.emit(_milestone_index)


func _on_learning_shown() -> void:
	tips_viewed += 1


## Only climate facts delivered as TIPs count (not "you need a seed" hints).
func _on_tip_requested(text_key: String) -> void:
	if text_key.begins_with("FACT_"):
		tips_viewed += 1
