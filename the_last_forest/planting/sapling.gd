class_name Sapling
extends Interactable
## A planted tree. Grows through 4 stages; can be nibbled by pests; can wilt
## and be revived (hold E) — it never dies permanently (no harsh loss for kids).
## Stage 2 barrier tool: hold E on a young sapling while carrying a Tree Guard
## to fence it — guarded saplings are ignored by pests (real reforestation
## projects use tree guards/shelters for exactly this).
##
## Scene (sapling.tscn):
##   Sapling (Area2D, this script)   — also the pests' target
##   ├─ CollisionShape2D  (small circle around the trunk base)
##   ├─ Sprite (Sprite2D)  (offset so the base sits at the origin)
##   ├─ ThirstyIcon (Sprite2D, optional)  (water-drop icon for Stage 3)
##   ├─ Guard (CanvasItem, optional)  (fence art, shown once guarded)
##   └─ Prompt (Label)  ("Hold E to help!")
##
## Growth state machine:
##   SEEDLING -> SPROUT -> YOUNG -> TREE (matured, safe, counts for restoration)
##   any non-TREE stage --(health 0)--> WILTED (growth frozen) --(hold E)--> same stage

enum Stage { SEEDLING, SPROUT, YOUNG, TREE }

## Seconds to go from stage i to i+1 (3 entries).
@export var stage_durations: Array[float] = [4.0, 6.0, 8.0]
## One texture per stage (4 entries). If empty, the Sprite is scaled instead.
@export var stage_textures: Array[Texture2D] = []
@export var max_health: int = 3
@export var wilted_tint: Color = Color(0.55, 0.42, 0.3)

var zone: PlantingZone = null
var stage: Stage = Stage.SEEDLING
var health: int = 3
var wilted: bool = false
var guarded: bool = false

var _growth: float = 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _thirsty_icon: CanvasItem = get_node_or_null(^"ThirstyIcon") as CanvasItem
@onready var _guard_visual: CanvasItem = get_node_or_null(^"Guard") as CanvasItem


func _ready() -> void:
	super()
	hold_time = 1.2
	prompt_key = "PROMPT_REVIVE"
	health = max_health
	add_to_group(&"saplings")
	_apply_stage_visual(false)
	if _thirsty_icon != null:
		_thirsty_icon.hide()
	if _guard_visual != null:
		_guard_visual.hide()


func _process(delta: float) -> void:
	if wilted or stage == Stage.TREE:
		return
	var blocked_by_drought: bool = stage >= Stage.SPROUT and zone != null and not zone.can_grow_past_sprout()
	if _thirsty_icon != null:
		_thirsty_icon.visible = blocked_by_drought
	if blocked_by_drought:
		return
	_growth += delta
	if _growth >= stage_durations[stage]:
		_growth = 0.0
		_advance_stage()


func _advance_stage() -> void:
	stage = (stage + 1) as Stage
	health = max_health
	_apply_stage_visual(true)
	EventBus.sapling_stage_changed.emit(self, stage)
	if stage == Stage.TREE:
		var burst := get_node_or_null(^"LeafBurst") as CPUParticles2D
		if burst != null:
			burst.position = Vector2(0, -_sprite.texture.get_height() * 0.6) if _sprite.texture else burst.position
			burst.restart()
		if _guard_visual != null:
			_guard_visual.hide()  # a grown tree no longer needs its fence
		EventBus.sapling_matured.emit(self)


## Pests only target vulnerable saplings.
func is_vulnerable() -> bool:
	return not wilted and not guarded and stage != Stage.TREE


func take_damage(amount: int) -> void:
	if not is_vulnerable():
		return
	health = maxi(0, health - amount)
	EventBus.sapling_damaged.emit(self, health)
	var flash := create_tween()
	flash.tween_property(_sprite, ^"modulate", Color(1, 0.5, 0.5), 0.08)
	flash.tween_property(_sprite, ^"modulate", Color.WHITE, 0.15)
	if health == 0:
		_wilt()


func _wilt() -> void:
	wilted = true
	_sprite.modulate = wilted_tint
	create_tween().tween_property(_sprite, ^"rotation", 0.25, 0.4)
	EventBus.sapling_wilted.emit(self)


# ------------------------------------------------------------------ Interactable (revive / guard)
func is_interactable() -> bool:
	return wilted or _can_guard()


func _can_guard() -> bool:
	return not guarded and stage != Stage.TREE and GameState.guards > 0


func set_highlighted(on: bool) -> void:
	prompt_key = "PROMPT_REVIVE" if wilted else "PROMPT_GUARD"
	if _prompt is Label:
		(_prompt as Label).text = tr(prompt_key)
	super(on)


func complete_interaction(_interactor: Node) -> void:
	if not wilted:
		if _can_guard() and GameState.try_spend_guard():
			guarded = true
			if _guard_visual != null:
				_guard_visual.show()
			set_highlighted(false)
			EventBus.sapling_guarded.emit(self)
		return
	wilted = false
	health = max_health
	_sprite.modulate = Color.WHITE
	create_tween().tween_property(_sprite, ^"rotation", 0.0, 0.3)
	set_highlighted(false)
	EventBus.sapling_revived.emit(self)


# ------------------------------------------------------------------ Visuals
func _apply_stage_visual(animate: bool) -> void:
	# Pixel-art stage textures are drawn at their final size -> scale 1.
	var target_scale: Vector2 = Vector2.ONE
	if stage_textures.size() > int(stage):
		_sprite.texture = stage_textures[stage]
	else:
		var legacy_scale: float = [0.5, 0.8, 1.1, 1.5][stage]
		target_scale = Vector2(legacy_scale, legacy_scale)
	if _sprite.texture != null:
		_sprite.centered = false
		_sprite.position = Vector2.ZERO
		_sprite.offset = Vector2(-_sprite.texture.get_width() * 0.5, -_sprite.texture.get_height())
	if animate:
		_sprite.scale = target_scale * Vector2(0.8, 1.25)
		create_tween().tween_property(_sprite, ^"scale", target_scale, 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_sprite.scale = target_scale
