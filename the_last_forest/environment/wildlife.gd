class_name Wildlife
extends Node2D
## "The forest comes back to life": pollinators and birds return as the
## stage is restored. Created at runtime by RestorationController, so no
## level scene needs editing.
##   milestone 2 (50 %)  -> butterflies around the young trees
##   milestone 4 (100 %) -> a flock of birds crosses the sky
## Purely visual: no collisions, never blocks the player.

const BUTTERFLY_TEX: Texture2D = preload("res://the_last_forest/art/butterfly.png")
const BIRD_TEX: Texture2D = preload("res://the_last_forest/art/bird.png")
const BUTTERFLY_TINTS: Array[Color] = [
	Color(1, 1, 1), Color(1.0, 0.85, 0.5), Color(0.75, 0.9, 1.0), Color(1.0, 0.75, 0.9),
]

var _critters: Array[Dictionary] = []
var _t: float = 0.0


func _ready() -> void:
	z_index = 5
	EventBus.restoration_milestone_reached.connect(_on_milestone)
	# Coming back to an already-restored stage (or a checkpoint) keeps them.
	var reached: int = GameState.milestone_index()
	if reached >= 1:
		_spawn_butterflies.call_deferred()
	if reached >= 3:
		_spawn_birds.call_deferred()


func _on_milestone(index: int) -> void:
	if index == 1:
		_spawn_butterflies()
	elif index == 3:
		_spawn_birds()


func _spawn_butterflies() -> void:
	var anchors: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(&"saplings"):
		if node is Node2D:
			anchors.append((node as Node2D).global_position + Vector2(0, -40))
	if anchors.is_empty():
		var p := get_tree().get_first_node_in_group(&"player") as Node2D
		if p != null:
			anchors.append(p.global_position + Vector2(0, -60))
	var i: int = 0
	for a: Vector2 in anchors:
		for k: int in 2:
			var s := _make_sprite(BUTTERFLY_TEX, 1.5)
			s.modulate = BUTTERFLY_TINTS[(i + k) % BUTTERFLY_TINTS.size()]
			s.global_position = a
			_critters.append({"node": s, "kind": "butterfly", "anchor": a,
					"phase": randf() * TAU, "speed": randf_range(0.6, 1.1), "r": randf_range(18.0, 34.0)})
			_fade_in(s)
		i += 1


func _spawn_birds() -> void:
	var cam := get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam != null else Vector2(400, 200)
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5
	for k: int in 5:
		var s := _make_sprite(BIRD_TEX, 1.6)
		var start := Vector2(center.x - half.x - 40.0 - k * 34.0, center.y - half.y + 50.0 + (k % 2) * 18.0 + k * 6.0)
		s.global_position = start
		_critters.append({"node": s, "kind": "bird", "phase": k * 0.7, "speed": randf_range(120.0, 150.0),
				"base_y": start.y, "left": center.x + half.x + 80.0})


func _make_sprite(tex: Texture2D, sc: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.hframes = 2
	s.scale = Vector2(sc, sc)
	add_child(s)
	return s


func _fade_in(item: CanvasItem) -> void:
	item.modulate.a = 0.0
	create_tween().tween_property(item, ^"modulate:a", 1.0, 1.2)


func _process(delta: float) -> void:
	_t += delta
	for c: Dictionary in _critters:
		if not is_instance_valid(c["node"]):
			continue
		var s: Sprite2D = c["node"]
		var ph: float = float(c["phase"])
		if c["kind"] == "butterfly":
			var tt: float = _t * float(c["speed"]) + ph
			var r: float = float(c["r"])
			var prev: Vector2 = s.global_position
			s.global_position = (c["anchor"] as Vector2) + Vector2(cos(tt) * r, sin(tt * 2.0) * r * 0.4)
			s.flip_h = s.global_position.x < prev.x
			s.frame = int(_t * 8.0 + ph) % 2
		else:
			s.global_position.x += float(c["speed"]) * delta
			s.global_position.y = float(c["base_y"]) + sin(_t * 3.0 + ph) * 6.0
			s.frame = int(_t * 6.0 + ph) % 2
			if s.global_position.x > float(c["left"]) + 600.0:
				s.queue_free()
	_critters = _critters.filter(func(c: Dictionary) -> bool: return is_instance_valid(c["node"]))
