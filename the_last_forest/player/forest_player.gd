class_name ForestPlayer
extends CharacterBody2D
## THE LAST FOREST player controller. Replaces player/player.gd.
## Removed from the demo: Gun, bullets, "shoot" input, *_weapon animations,
## split-screen action_suffix, and the implicit invincibility (damage now
## flows through GameState's 3 hearts).
##
## State machine
##   GROUNDED  --jump-->                 AIRBORNE
##   GROUNDED  --interactor.is_busy()--> PLANTING   (hold E started)
##   AIRBORNE  --land-->                 GROUNDED
##   PLANTING  --hold done / released--> GROUNDED
##   any       --player_damaged-->       HURT (0.35 s, input ignored, knockback)
##   HURT      --timer-->                GROUNDED / AIRBORNE
##
## PLANTING locks horizontal motion: move input and jump are ignored and the
## body brakes to a stop, so a child can't slide off the soil mid-plant.
## (PlayerInteractor still cancels on release of E, or on pressing jump as an
## escape hatch — pressing jump in PLANTING cancels, it does not jump.)

enum State { GROUNDED, AIRBORNE, PLANTING, HURT }

const WALK_SPEED: float = 300.0
const ACCELERATION: float = WALK_SPEED * 6.0
const PLANT_BRAKE: float = WALK_SPEED * 12.0
const JUMP_VELOCITY: float = -725.0
const TERMINAL_VELOCITY: float = 700.0
## Demo multiplied x-speed by 2.5 on double jump; gentler for young players.
const DOUBLE_JUMP_BOOST: float = 1.4
const HURT_SECONDS: float = 0.35
const PEST_REPEL_RANGE: float = 72.0

var state: State = State.GROUNDED

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 2100.0)
var _double_jump_charged: bool = false
var _hurt_left: float = 0.0

@onready var _platform_detector: RayCast2D = $PlatformDetector
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _jump_sound: AudioStreamPlayer2D = $Jump
@onready var _interactor: PlayerInteractor = $PlayerInteractor


func _ready() -> void:
	add_to_group(&"player")
	_interactor.cancel_on_move = false  # PLANTING locks movement instead.
	EventBus.player_damaged.connect(_on_player_damaged)


func _physics_process(delta: float) -> void:
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + _gravity * delta)

	match state:
		State.GROUNDED, State.AIRBORNE:
			_process_movement(delta)
			if is_on_floor() and _interactor.is_busy():
				_set_state(State.PLANTING)
		State.PLANTING:
			velocity.x = move_toward(velocity.x, 0.0, PLANT_BRAKE * delta)
			if not _interactor.is_busy():
				_set_state(State.GROUNDED)
		State.HURT:
			_hurt_left -= delta
			if _hurt_left <= 0.0:
				_set_state(State.GROUNDED if is_on_floor() else State.AIRBORNE)

	floor_stop_on_slope = not _platform_detector.is_colliding()
	move_and_slide()

	if state == State.GROUNDED and not is_on_floor():
		_set_state(State.AIRBORNE)
	elif state == State.AIRBORNE and is_on_floor():
		_set_state(State.GROUNDED)

	_update_visuals()


func _process_movement(delta: float) -> void:
	if Input.is_action_just_pressed(&"interact"):
		_repel_nearby_pests()
	if is_on_floor():
		_double_jump_charged = true
	if Input.is_action_just_pressed(&"jump"):
		_try_jump()
	elif Input.is_action_just_released(&"jump") and velocity.y < 0.0:
		velocity.y *= 0.6  # variable jump height
	var target_x: float = Input.get_axis(&"move_left", &"move_right") * WALK_SPEED
	velocity.x = move_toward(velocity.x, target_x, ACCELERATION * delta)


func _repel_nearby_pests() -> void:
	for candidate: Node in get_tree().get_nodes_in_group(&"pests"):
		if candidate is Pest:
			var pest := candidate as Pest
			if global_position.distance_squared_to(pest.global_position) <= PEST_REPEL_RANGE * PEST_REPEL_RANGE:
				pest.repel(global_position)


func _try_jump() -> void:
	if is_on_floor():
		_jump_sound.pitch_scale = 1.0
	elif _double_jump_charged:
		_double_jump_charged = false
		velocity.x *= DOUBLE_JUMP_BOOST
		_jump_sound.pitch_scale = 1.5
	else:
		return
	velocity.y = JUMP_VELOCITY
	_jump_sound.play()
	_set_state(State.AIRBORNE)


func _set_state(new_state: State) -> void:
	state = new_state


func _on_player_damaged(_amount: int) -> void:
	_interactor.cancel_interaction()
	_hurt_left = HURT_SECONDS
	_set_state(State.HURT)


func _update_visuals() -> void:
	if not is_zero_approx(velocity.x) and state != State.PLANTING:
		_sprite.scale.x = 1.0 if velocity.x > 0.0 else -1.0
	# Blink while invulnerable after a hit.
	_sprite.visible = not GameState.is_invulnerable() or (Time.get_ticks_msec() / 80) % 2 == 0
	var anim: StringName
	match state:
		State.PLANTING:
			anim = &"crouch"
		State.GROUNDED:
			anim = &"run" if absf(velocity.x) > 0.1 else &"idle"
		_:
			anim = &"falling" if velocity.y > 0.0 else &"jumping"
	if _animation_player.has_animation(anim) and anim != _animation_player.current_animation:
		_animation_player.play(anim)
