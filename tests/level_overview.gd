extends SceneTree
## Renders every stage as one long strip image (burnt and restored) for review.
## Run (needs a display, e.g. xvfb-run):
##   godot --path . --rendering-driver opengl3 -s res://tests/level_overview.gd
## Output: user://overview/stage_N_burnt.png and stage_N_green.png

func _initialize() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://overview"))
	for idx in range(1, 5):
		for mode in ["burnt", "green"]:
			await _render(idx, mode)
	quit()


func _render(idx: int, mode: String) -> void:
	var sc: Node = load("res://the_last_forest/scenes/stage_%d.tscn" % idx).instantiate()
	root.add_child(sc)
	await create_timer(0.3, true).timeout
	root.get_node("LearningDirector").clear_queue()
	var q = sc.find_child("QuizModal", true, false)
	if q: q.hide()
	sc.get_node("HUDLayer").visible = false
	root.get_node("GameState").clear_pauses()
	paused = false
	var ctl = sc.get_node("RestorationController")
	if mode == "green":
		for tier in range(1, 5):
			ctl._on_milestone(tier - 1)
	await create_timer(1.2, true).timeout
	ctl.set_process(false)
	if ctl._tween: ctl._tween.kill()
	ctl._set_value(0.0 if mode == "burnt" else 1.0)
	var player: Node2D = sc.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var cam := Camera2D.new()
	sc.add_child(cam)
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.make_current()
	var tiles: TileMapLayer = sc.get_node("TileMapLayer")
	var used := tiles.get_used_rect()
	var width := used.end.x * 64
	var strip := Image.create(width, 576, false, Image.FORMAT_RGBA8)
	var x := 0
	while x < width:
		cam.position = Vector2(x, 352)
		await process_frame; await process_frame; await process_frame
		var img := root.get_texture().get_image()
		img.resize(800, 480, Image.INTERPOLATE_NEAREST)
		strip.blit_rect(img, Rect2i(0, 0, mini(800, width - x), 480), Vector2i(x, 0))
		x += 800
	strip.crop(width, 480)
	strip.save_png("user://overview/stage_%d_%s.png" % [idx, mode])
	print("saved stage ", idx, " ", mode, " width ", width)
	sc.queue_free()
	await process_frame
