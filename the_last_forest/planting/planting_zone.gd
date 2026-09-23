class_name PlantingZone
extends Interactable
## A patch of burnt soil where exactly one sapling can be planted.
## Scene (planting_zone.tscn):
##   PlantingZone (Area2D, this script)
##   ├─ CollisionShape2D        (RectangleShape2D ~40x24, sits on the ground)
##   ├─ Soil (Sprite2D)         (burnt soil / glowing marker)
##   ├─ SaplingAnchor (Marker2D) (where the sapling's base goes)
##   └─ Prompt (Label)           ("Hold E", auto-shown when targeted)

## Assign sapling.tscn here.
@export var sapling_scene: PackedScene
## Stage 3: link to the AridZone this soil sits in. Saplings here can't grow
## past SPROUT until that zone is hydrated. Leave empty on other stages.
@export var arid_zone: AridZone

var sapling: Sapling = null

@onready var _anchor: Marker2D = $SaplingAnchor
@onready var _soil: CanvasItem = get_node_or_null(^"Soil") as CanvasItem
@onready var _progress: ProgressBar = get_node_or_null(^"ProgressBar") as ProgressBar


func _ready() -> void:
	super()
	add_to_group(&"planting_zones")
	if _progress != null:
		_progress.hide()
	EventBus.interaction_started.connect(_on_interaction_started_event)
	EventBus.interaction_progress.connect(_on_interaction_progress_event)
	EventBus.interaction_cancelled.connect(_on_interaction_ended_event)
	EventBus.interaction_completed.connect(_on_interaction_ended_event)


func is_interactable() -> bool:
	return sapling == null


func get_block_reason(_interactor: Node) -> StringName:
	if sapling != null:
		return &"occupied"
	if GameState.seeds <= 0:
		return &"no_seeds"
	return &""


func on_interaction_started(_interactor: Node) -> void:
	if _soil != null:
		create_tween().tween_property(_soil, ^"scale", Vector2(1.1, 0.9), 0.15)


func on_interaction_cancelled(_interactor: Node) -> void:
	if _soil != null:
		create_tween().tween_property(_soil, ^"scale", Vector2.ONE, 0.15)


func complete_interaction(_interactor: Node) -> void:
	if sapling != null or sapling_scene == null:
		return
	if not GameState.try_spend_seed():
		EventBus.interaction_denied.emit(self, &"no_seeds")
		return
	sapling = sapling_scene.instantiate() as Sapling
	sapling.zone = self
	sapling.position = _anchor.position
	add_child(sapling)
	set_highlighted(false)
	if _soil != null:
		_soil.scale = Vector2.ONE
	EventBus.tree_planted.emit(self, sapling)
	if _progress != null:
		_progress.hide()
	monitorable = false
	monitoring = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)


## Asked by the Sapling every frame it wants to grow.
func can_grow_past_sprout() -> bool:
	return arid_zone == null or arid_zone.is_hydrated()


func _on_interaction_started_event(target: Node2D) -> void:
	if target == self and _progress != null:
		_progress.value = 0.0
		_progress.show()


func _on_interaction_progress_event(target: Node2D, ratio: float) -> void:
	if target == self and _progress != null:
		_progress.value = ratio * 100.0


func _on_interaction_ended_event(target: Node2D) -> void:
	if target == self and _progress != null:
		_progress.hide()
