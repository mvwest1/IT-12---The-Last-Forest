extends SceneTree
## Renders key screens to PNG for visual review (needs a real renderer:
##   xvfb-run godot --rendering-driver opengl3 --path . -s res://tests/screenshots.gd)
var out_dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://shots"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	var app = root.get_node("AppFlow"); var gs = root.get_node("GameState"); var ld = root.get_node("LearningDirector")
	app.go_main_menu(); await wait(0.6); await shot("01_main_menu")
	app.go_login(); await wait(0.6); await shot("02_login")
	app.student_id = 1; app.student_display_name = "Ana"; app.grade_section = "4-Sampaguita"
	app.go_stage_select(); await wait(0.6); await shot("03_stage_select")
	app.start_stage(1); await wait(1.2); await shot("04_quiz_pre")
	var q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(2.0); await shot("05_fact_card")
	var card = current_scene.find_child("FactCardPopup", true, false); if card.visible: card._close()
	await wait(0.8); await shot("06_stage1_start")
	gs.add_seeds(5)
	for z in get_nodes_in_group("planting_zones"): z.complete_interaction(null)
	for s in get_nodes_in_group("saplings"): s._growth = 999.0; s._process(0.0)
	await wait(0.4)
	for s in get_nodes_in_group("saplings"): s._growth = 999.0; s._process(0.0)
	await wait(0.6); await shot("07_stage1_growing")
	for k in 2:
		for s in get_nodes_in_group("saplings"): s._growth = 999.0; s._process(0.0)
		await wait(0.3)
	ld.clear_queue(); gs.clear_pauses()
	for c in [current_scene.find_child("FactCardPopup", true, false)]:
		if c and c.visible: c.hide()
	await wait(2.0); await shot("08_stage1_restored")
	app.start_stage(3); await wait(1.2)
	q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(0.3); ld.clear_queue(); var c3 = current_scene.find_child("FactCardPopup", true, false); if c3.visible: c3.hide()
	gs.clear_pauses(); current_scene.get_node("Player").global_position = Vector2(300, 600)
	current_scene.get_node("Diverter").complete_interaction(null)
	await wait(3.0); await shot("09_stage3_water")
	app.start_stage(2); await wait(1.2)
	q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(0.3); ld.clear_queue(); var c2 = current_scene.find_child("FactCardPopup", true, false); if c2.visible: c2.hide()
	gs.clear_pauses(); current_scene.get_node("Player").global_position = Vector2(400, 600)
	await wait(2.0); await shot("10_stage2_pests")
	# Pause menu + Leaf Journal + tutorial hint
	app.start_stage(1); await wait(1.2)
	q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(2.0); var c1 = current_scene.find_child("FactCardPopup", true, false); if c1.visible: c1._close()
	await wait(0.5)
	var pause = current_scene.find_child("PauseOverlay", true, false); pause.open(); await wait(0.4); await shot("12_pause")
	pause._open_journal(); await wait(0.4); await shot("13_journal")
	pause.close(); await wait(0.3)
	var hud = current_scene.get_node("HUDLayer/HUD"); hud.show_climate_tip({"title": "SIGN_2_TITLE", "text": "SIGN_2_BODY"}); await wait(0.6)
	await shot("14_sign_hint")
	hud._climate_can_close = true; hud._dismiss_climate_tip(); await wait(0.3)
	current_scene.get_node("Player").global_position = current_scene.get_node("PlantingZones/Zone1").global_position + Vector2(0, -12)
	await wait(0.6); await shot("15_plant_prompt")
	app.go_main_menu(); await wait(0.6); current_scene.find_child("TeacherButton", true, false).pressed.emit(); await wait(0.4); await shot("16_teacher")
	app.last_result = {"stage_index": 1, "seeds_collected": 5, "trees_matured": 3, "duration": 184.0, "tips_viewed": 3, "pre_score": 1, "post_score": 3, "quiz_total": 3, "saved": true, "guest": false}
	app.current_stage_index = 1
	app.goto(app.STAGE_CLEAR); await wait(0.8); await shot("11_stage_clear")
	quit()

func wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func shot(name: String) -> void:
	await process_frame; await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())
