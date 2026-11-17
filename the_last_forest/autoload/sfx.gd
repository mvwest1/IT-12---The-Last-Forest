extends Node
## Sfx (Autoload) — plays short sound effects in response to EventBus
## signals, so gameplay scripts never need to know about audio.
## Every Button in the game gets a click sound automatically.

const SOUNDS: Dictionary = {
	&"seed_pickup": preload("res://the_last_forest/audio/seed_pickup.wav"),
	&"plant": preload("res://the_last_forest/audio/plant.wav"),
	&"tree_grown": preload("res://the_last_forest/audio/tree_grown.wav"),
	&"shoo": preload("res://the_last_forest/audio/shoo.wav"),
	&"lever": preload("res://the_last_forest/audio/lever.wav"),
	&"water": preload("res://the_last_forest/audio/water.wav"),
	&"hurt": preload("res://the_last_forest/audio/hurt.wav"),
	&"ui_click": preload("res://the_last_forest/audio/ui_click.wav"),
	&"card_open": preload("res://the_last_forest/audio/card_open.wav"),
	&"quiz_done": preload("res://the_last_forest/audio/quiz_done.wav"),
	&"stage_clear": preload("res://the_last_forest/audio/stage_clear.wav"),
}
const VOICES: int = 6
const MIN_GAP_MSEC: int = 90

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	EventBus.seed_collected.connect(func(_a: int, _p: Vector2) -> void: play(&"seed_pickup"))
	EventBus.tree_planted.connect(func(_z: Node2D, _s: Node2D) -> void: play(&"plant"))
	EventBus.sapling_matured.connect(func(_s: Node2D) -> void: play(&"tree_grown"))
	EventBus.pest_repelled.connect(func(_p: Node2D) -> void: play(&"shoo"))
	EventBus.diverter_toggled.connect(func(_d: Node2D, _b: bool) -> void: play(&"lever"))
	EventBus.water_delivered.connect(func(_z: Node2D, _a: int) -> void: play(&"water", 400))
	EventBus.player_damaged.connect(func(_a: int) -> void: play(&"hurt"))
	EventBus.fact_card_opened.connect(func(_f: StringName) -> void: play(&"card_open"))
	EventBus.quiz_finished.connect(func(_i: int, _ph: StringName, _s: int, _t: int) -> void: play(&"quiz_done"))
	EventBus.stage_cleared.connect(func() -> void: play(&"stage_clear"))
	get_tree().node_added.connect(_on_node_added)


func play(sound: StringName, min_gap_msec: int = MIN_GAP_MSEC) -> void:
	if not SOUNDS.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < min_gap_msec:
		return
	_last_played[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = SOUNDS[sound]
	p.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not (node as BaseButton).pressed.is_connected(_click):
		(node as BaseButton).pressed.connect(_click)


func _click() -> void:
	play(&"ui_click")
