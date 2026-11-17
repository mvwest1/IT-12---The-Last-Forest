extends SceneTree
## Screenshots of the v1.0.0 screens for the defense deck and docs.
##   SHOT_DIR=/abs/dir xvfb-run godot --rendering-driver opengl3 --path . \
##       --resolution 1600x720 -s res://tests/production_shots.gd
var out_dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://shots_v1"
var app: Node
var db: Node
var gs: Node
var ld: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	await process_frame
	app = root.get_node("AppFlow"); db = root.get_node("DatabaseManager")
	gs = root.get_node("GameState"); ld = root.get_node("LearningDirector")
	db._close(); db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shots_v1.db"))
	db.init_db_at("user://shots_v1.db")
	_seed_class()
	app.login("900000000001", "Mika", "4-Sampaguita")
	await wait(0.3)
	for f in [&"fact_forest_home", &"fact_trees_store_carbon", &"fact_roots_hold_soil", &"fact_burning_releases_co2"]:
		gs.unlock_fact(f)
	app.go_main_menu(); await wait(0.8); await shot("v1_01_main_menu")
	current_scene._on_teacher(); current_scene._pin.text = LocalSettings.value("teacher_pin")
	current_scene._on_primary(); await wait(0.4); await shot("v1_02_teacher_dashboard")
	app.goto(app.STORY); await wait(0.8); await shot("v1_03_story_1")
	current_scene._advance(); current_scene._advance(); await wait(0.6); await shot("v1_04_story_3")
	app.goto(app.LEADERBOARD); await wait(0.8); await shot("v1_05_leaderboard")
	app.goto(app.JOURNAL); await wait(0.8); await shot("v1_06_journal")
	current_scene._open_page(ld.get_fact(&"fact_trees_store_carbon")); await wait(0.5); await shot("v1_07_journal_page_bilingual")
	app.goto(app.SETTINGS); await wait(0.8); await shot("v1_08_settings")
	# Gameplay
	app.start_stage(1); await wait(1.2)
	var q = current_scene.find_child("QuizModal", true, false); await shot("v1_09_pre_quiz")
	q.hide(); q.finished.emit(1)
	await wait(0.5); ld.clear_queue(); gs.clear_pauses()
	ld.request_fact(&"fact_roots_hold_soil", 2, true)
	await wait(2.0); await shot("v1_10_fact_card_bilingual")
	_close_cards(); _show_touch(); await wait(0.6); await shot("v1_11_stage1_touch_controls")
	gs.add_seeds(5)
	for z in get_nodes_in_group("planting_zones"): z.complete_interaction(null)
	for k in 4:
		for s in get_nodes_in_group("saplings"): s._growth = 999.0; s._process(0.0)
		await wait(0.3)
	ld.clear_queue(); gs.clear_pauses(); _close_cards()
	await wait(2.0); await shot("v1_12_stage1_restored_wildlife")
	app.start_stage(2); await wait(1.2)
	q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(0.3); ld.clear_queue(); _close_cards(); gs.clear_pauses()
	var p2: Node2D = current_scene.get_node("Pest2")
	current_scene.get_node("Player").global_position = p2.global_position + Vector2(-140, 0)
	await wait(1.0); await shot("v1_13_stage2_beetle_caterpillar")
	app.start_stage(3); await wait(1.2)
	q = current_scene.find_child("QuizModal", true, false); q.hide(); q.finished.emit(0)
	await wait(0.3); ld.clear_queue(); _close_cards(); gs.clear_pauses()
	current_scene.get_node("Player").global_position = current_scene.get_node("Diverter").global_position + Vector2(-60, -20)
	current_scene.get_node("Diverter").complete_interaction(null)
	await wait(2.5); await shot("v1_14_stage3_sluice")
	app.last_result = {"stage_index": 1, "seeds_collected": 6, "trees_matured": 3, "duration": 84.0,
			"tips_viewed": 3, "pre_score": 1, "post_score": 3, "quiz_total": 3, "saved": true, "guest": false,
			"score": 300 + 75 + 30 + 108, "previous_best": 0}
	app.current_stage_index = 1
	app.goto(app.STAGE_CLEAR); await wait(1.4); await shot("v1_15_stage_clear_points")
	db._close()
	quit()


func _seed_class() -> void:
	var names := ["Mika", "", "Jun", "Bea", "", "Paolo", "Lara", ""]
	for i in names.size():
		var sid: int = db.register_student("9000000000%02d" % (i + 1), "", "4-Sampaguita" if i < 6 else "4-Rosal")
		if names[i] != "": db.set_nickname(sid, names[i])
		for stage in range(1, 1 + (i % 4) + 1):
			var att: String = db.new_attempt_id(sid, stage)
			db.save_pre_quiz(sid, stage, i % 3, att)
			db.save_stage_completion(sid, stage, -1, 1 + (i + stage) % 3, 4, 3 + (i % 2), 70.0 + 13 * i, 2 + (i % 2), att, i % 3)


func _close_cards() -> void:
	for c in [current_scene.find_child("FactCardPopup", true, false)]:
		if c and c.visible: c.hide()
	ld.clear_queue(); gs.clear_pauses()


func _show_touch() -> void:
	for b in current_scene.get_node("Player/UI").get_children():
		if b is TouchScreenButton: b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS


func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("shot ", name)
