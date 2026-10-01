class_name RestorationController
extends Node
## Put one in each stage scene. Turns GameState progress into visuals:
##
## 1. Smoothly tweens the GLOBAL shader uniform "restoration" (0 = burnt,
##    1 = green). Every CanvasItem using restoration.gdshader (tiles, props,
##    background) updates from this one value.
##    Requires: Project Settings > Shader Globals > add "restoration" (float, 0).
##
## 2. Milestone tiers via groups (no code per level — just tag nodes):
##    "appear_at_1".."appear_at_4"  -> hidden until milestone N, then fade in
##    "vanish_at_1".."vanish_at_4"  -> fade out at milestone N (ash, stumps)
##    "celebrate_at_1".."_4"        -> GPUParticles2D/CPUParticles2D: emit once
##    (milestone 1 = 25 %, 2 = 50 %, 3 = 75 %, 4 = 100 % of the stage goal)

const PARAM: StringName = &"restoration"
const RESTORATION_SHADER: Shader = preload("res://the_last_forest/environment/restoration.gdshader")
const RESTORATION_WIND_SHADER: Shader = preload("res://the_last_forest/environment/restoration_wind.gdshader")

@export var tween_duration: float = 1.5
## 3. Auto-apply: every CanvasItem under these top-level nodes (by name) gets
##    the burnt->green shader, so level art needs no manual wiring. Props that
##    use the demo wind_sway material keep their sway (restoration_wind shader).
##    Gameplay nodes (Player, saplings, pickups, HUD) are never touched.
@export var auto_apply: bool = true
@export var decor_root_names: PackedStringArray = [
	"TileMapLayer", "Background", "ParallaxBackground", "Grass", "Flowers", "Trees", "Bushes",
	"Rocks", "Props", "Vines", "Ferns", "Platforms", "Decor",
]

var _plain_material: ShaderMaterial = null
var _wind_materials: Dictionary = {}  # original Material -> converted ShaderMaterial

var _current: float = 0.0
var _tween: Tween = null


func _ready() -> void:
	if auto_apply:
		_apply_materials()
	EventBus.restoration_changed.connect(_on_restoration_changed)
	EventBus.restoration_milestone_reached.connect(_on_milestone)
	_set_value(GameState.restoration_ratio())
	var reached: int = GameState.milestone_index()
	for tier: int in range(1, 5):
		var done: bool = tier - 1 <= reached
		for node: Node in get_tree().get_nodes_in_group(StringName("appear_at_%d" % tier)):
			if node is CanvasItem:
				(node as CanvasItem).visible = done
		for node: Node in get_tree().get_nodes_in_group(StringName("vanish_at_%d" % tier)):
			if node is CanvasItem:
				(node as CanvasItem).visible = not done


func _on_restoration_changed(ratio: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_value, _current, ratio, tween_duration) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_value(value: float) -> void:
	_current = value
	RenderingServer.global_shader_parameter_set(PARAM, value)


func _on_milestone(index: int) -> void:
	var tier: int = index + 1
	for node: Node in get_tree().get_nodes_in_group(StringName("appear_at_%d" % tier)):
		if node is CanvasItem:
			var item := node as CanvasItem
			item.modulate.a = 0.0
			item.show()
			create_tween().tween_property(item, ^"modulate:a", 1.0, 1.0)
	for node: Node in get_tree().get_nodes_in_group(StringName("vanish_at_%d" % tier)):
		if node is CanvasItem:
			var item := node as CanvasItem
			var tw := create_tween()
			tw.tween_property(item, ^"modulate:a", 0.0, 1.0)
			tw.tween_callback(item.hide)
	for node: Node in get_tree().get_nodes_in_group(StringName("celebrate_at_%d" % tier)):
		if node is GPUParticles2D:
			(node as GPUParticles2D).restart()
		elif node is CPUParticles2D:
			(node as CPUParticles2D).restart()


# ------------------------------------------------------------------ Auto-apply
func _apply_materials() -> void:
	var stage_root: Node = owner if owner != null else get_parent()
	if stage_root == null:
		return
	_plain_material = ShaderMaterial.new()
	_plain_material.shader = RESTORATION_SHADER
	for root_name: String in decor_root_names:
		var node: Node = stage_root.get_node_or_null(NodePath(root_name))
		if node != null:
			_apply_recursive(node)


func _apply_recursive(node: Node) -> void:
	if node is CanvasItem:
		var item := node as CanvasItem
		var mat: Material = item.material
		if mat == null:
			item.material = _plain_material
		elif mat is ShaderMaterial and (mat as ShaderMaterial).shader != null \
				and (mat as ShaderMaterial).shader != RESTORATION_SHADER \
				and (mat as ShaderMaterial).shader != RESTORATION_WIND_SHADER:
			item.material = _converted_wind(mat as ShaderMaterial)
	for child: Node in node.get_children():
		_apply_recursive(child)


## Converts the demo's wind_sway material to the wind+restoration shader,
## keeping its sway parameters. Converted once per source material.
func _converted_wind(source: ShaderMaterial) -> ShaderMaterial:
	if _wind_materials.has(source):
		return _wind_materials[source]
	var out := ShaderMaterial.new()
	out.shader = RESTORATION_WIND_SHADER
	for param: Dictionary in RESTORATION_WIND_SHADER.get_shader_uniform_list():
		var pname: String = param["name"]
		var value: Variant = source.get_shader_parameter(pname)
		if value != null:
			out.set_shader_parameter(pname, value)
	_wind_materials[source] = out
	return out
