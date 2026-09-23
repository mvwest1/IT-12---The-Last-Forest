extends Node
## GameState (Autoload #2) — the single source of truth for run data.
##
## Replaces the idea of a narrow "SeedManager": seeds, trees, water, hearts and
## milestones are interdependent, so they live together here. Mutate ONLY via
## the methods below; each mutation is announced on EventBus.
##
## Also owns PAUSE. Never write get_tree().paused directly anywhere else —
## call request_pause(owner) / release_pause(owner) so the pause menu and a
## fact card can never unpause each other.

const MAX_HEARTS: int = 3
const INVULNERABLE_MSEC: int = 1200
## Fractions of the stage tree goal that trigger visual/learning milestones.
const MILESTONES: Array[float] = [0.25, 0.5, 0.75, 1.0]

var seeds: int = 0
var trees_planted: int = 0
## Trees that survived to full size. Restoration is driven by THIS, not by
## trees_planted — the lesson is "a planted tree only counts if it survives".
var trees_matured: int = 0
var tree_goal: int = 1
var hearts: int = MAX_HEARTS
var water_carried: int = 0
var water_capacity: int = 3
var unlocked_facts: Array[StringName] = []
var checkpoint_position: Vector2 = Vector2.ZERO
var current_stage: StageData = null

var _base_restoration: float = 0.0
var _milestone_index: int = -1
var _invulnerable_until: int = 0
var _pause_owners: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.tree_planted.connect(_on_tree_planted)
	EventBus.sapling_matured.connect(_on_sapling_matured)


# ------------------------------------------------------------------ Stage
func start_stage(data: StageData) -> void:
	current_stage = data
	seeds = data.starting_seeds
	trees_planted = 0
	trees_matured = 0
	tree_goal = maxi(1, data.tree_goal)
	_base_restoration = data.base_restoration
	water_carried = 0
	hearts = MAX_HEARTS
	_milestone_index = -1
	_pause_owners.clear()
	get_tree().paused = false
	_broadcast_all()


func _broadcast_all() -> void:
	EventBus.seeds_changed.emit(seeds)
	EventBus.trees_planted_changed.emit(trees_planted, tree_goal)
	EventBus.water_changed.emit(water_carried, water_capacity)
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
func add_seeds(amount: int) -> void:
	seeds += amount
	EventBus.seeds_changed.emit(seeds)


func try_spend_seed() -> bool:
	if seeds <= 0:
		return false
	seeds -= 1
	EventBus.seeds_changed.emit(seeds)
	return true


# ------------------------------------------------------------------ Water
func add_water(amount: int) -> bool:
	if water_carried >= water_capacity:
		return false
	water_carried = mini(water_capacity, water_carried + amount)
	EventBus.water_collected.emit(amount)
	EventBus.water_changed.emit(water_carried, water_capacity)
	return true


func try_spend_water() -> bool:
	if water_carried <= 0:
		return false
	water_carried -= 1
	EventBus.water_changed.emit(water_carried, water_capacity)
	return true


# ------------------------------------------------------------------ Health
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


# ------------------------------------------------------------------ Listeners
func _on_tree_planted(_zone: Node2D, _sapling: Node2D) -> void:
	trees_planted += 1
	EventBus.trees_planted_changed.emit(trees_planted, tree_goal)


func _on_sapling_matured(_sapling: Node2D) -> void:
	trees_matured += 1
	EventBus.restoration_changed.emit(restoration_ratio())
	var progress: float = goal_progress()
	while _milestone_index + 1 < MILESTONES.size() and progress >= MILESTONES[_milestone_index + 1] - 0.0001:
		_milestone_index += 1
		EventBus.restoration_milestone_reached.emit(_milestone_index)
