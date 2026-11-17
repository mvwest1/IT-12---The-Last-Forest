extends SceneTree
## Captures the moment-to-moment flow of a stage (start, quiz, play, end)
## so the pacing can be reviewed frame by frame.
##   SHOT_DIR=/abs xvfb-run godot --rendering-driver opengl3 --path . --resolution 1600x720 -s res://tests/flow_shots.gd
var out_dir := OS.get_environment("SHOT_DIR")
var n := 0
func _initialize() -> void:
	await process_frame
	var app = root.get_node("AppFlow"); var db = root.get_node("DatabaseManager"); var gs = root.get_node("GameState")
	db._close(); db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://flow.db")); db.init_db_at("user://flow.db")
	app.login("900000000009", "Kai", "4-A"); await wait(0.5)
	app.start_stage(1); await wait(0.6); await shot("pre_intro")
	var q = current_scene.find_child("QuizModal", true, false)
	q.start_questions(); await wait(0.15); await shot("q1_fading_in")
	await wait(0.4); q._on_choice(0); await wait(0.1); await shot("q1_tapped_pre")
	for i in 2:
		await wait(1.3); q._on_choice(1)
	await wait(1.0); await shot("pre_done")
	q._finish_quiz(); await wait(0.5); await shot("stage_banner")
	await wait(2.2); await shot("intro_card_after_breather")
	var card = current_scene.find_child("FactCardPopup", true, false)
	await wait(0.6); if card.visible: card._close()
	await wait(1.0); await shot("playing")
	var pause = current_scene.find_child("PauseOverlay", true, false)
	pause.open(); await wait(0.3); pause._on_stage_select(); await wait(0.2); await shot("pause_leave_confirm")
	pause.close(); gs.clear_pauses()
	# post quiz
	app.start_stage(1); await wait(0.6)
	q = current_scene.find_child("QuizModal", true, false)
	q.hide(); q.finished.emit(0); await wait(0.3)
	q.present(current_scene.get_node("StageController").quiz, &"post"); await wait(0.4); await shot("post_intro")
	q.start_questions(); await wait(0.6)
	var wrong: int = (q._quiz.questions[0].correct_index + 1) % 3
	q._on_choice(q._order.find(wrong)); await wait(0.3); await shot("post_wrong_feedback")
	for i in 2:
		await wait(2.3); q._on_choice(q._order.find(q._quiz.questions[q._index].correct_index))
	await wait(2.6); await shot("post_stars")
	quit()
func wait(s: float) -> void:
	await create_timer(s, true, false, true).timeout
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	root.get_texture().get_image().save_png(out_dir.path_join("%02d_%s.png" % [n, name]))
