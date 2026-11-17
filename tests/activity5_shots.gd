extends SceneTree
## Activity 5 evidence: plays the real flow (login -> quiz -> stage -> save ->
## retrieve) against a SEPARATE demo database and saves labelled screenshots.
## Run (needs a renderer):
##   godot --path . --rendering-driver opengl3 -s res://tests/activity5_shots.gd
## Output: user://activity5/*.png and the demo DB user://activity5_demo.db

const OUT := "user://activity5"
const DEMO_DB := "user://activity5_demo.db"

var app: Node
var gs: Node
var ld: Node
var db: Node


func _initialize() -> void:
	await process_frame
	app = root.get_node("AppFlow"); gs = root.get_node("GameState")
	ld = root.get_node("LearningDirector"); db = root.get_node("DatabaseManager")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	db._close(); db.set("_ready_ok", false)
	for suffix in ["", "-wal", "-shm"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEMO_DB + suffix))
	db.init_db_at(DEMO_DB)

	app.go_main_menu(); await wait(0.8); await shot("01_main_menu_database_ready")

	# INPUT: the player types LRN, name, grade/section.
	app.go_login(); await wait(0.6)
	var login: Node = current_scene
	login._lrn.text = "123456789012"; login._name.text = "Ana"; login._grade.text = "4-Sampaguita"
	await wait(0.3); await shot("02_player_input_login")
	login._on_continue(); await wait(0.8)
	await shot("03_stage_select_before_playing")
	current_scene._open_records(); await wait(0.4); await shot("04_my_records_empty_before_saving")
	current_scene._close_records()

	await play_stage(1, [1, 0, 0], true)
	await play_stage(2, [0, 1, 0], false)

	app.go_stage_select(); await wait(0.8); await shot("10_stage_select_after_retrieval")
	current_scene._open_records(); await wait(0.5); await shot("11_my_records_retrieved_from_sqlite")

	app.go_main_menu(); await wait(0.6)
	var menu: Node = current_scene
	menu._on_teacher(); await wait(0.3)
	menu._pin.text = LocalSettings.value("teacher_pin"); menu._on_export(); await wait(0.4)
	menu._pin.text = "••••"
	await shot("12_teacher_csv_export")
	print("DB file: ", ProjectSettings.globalize_path(DEMO_DB))
	db._close()
	quit()


## wrong_pre: 1 = answer that pre-quiz question wrongly (realistic pre-test).
func play_stage(idx: int, wrong_pre: Array, take_shots: bool) -> void:
	app.start_stage(idx); await wait(1.0)
	var sc: Node = current_scene
	var quiz: Node = sc.find_child("QuizModal", true, false)
	await until(func() -> bool: return quiz.visible)
	if take_shots: await shot("05_pre_quiz_player_answers")
	await answer(quiz, wrong_pre)
	await close_cards(sc)
	var player: CharacterBody2D = sc.get_node("Player")
	var zones: Array[Node] = get_nodes_in_group(&"planting_zones")
	gs.add_seeds(zones.size() + 2)
	player.global_position = zones[0].global_position + Vector2(0, -12)
	await wait(0.6)
	if take_shots: await shot("06_gameplay_action_planting")
	for z: Node in zones:
		if z.sapling == null: z.complete_interaction(null)
	for k in 4:
		for s: Node in get_nodes_in_group(&"saplings"):
			if is_instance_valid(s) and not s.wilted:
				s._growth = 999.0; s._process(0.0)
		await physics(3)
	await close_cards(sc)
	await wait(1.6)
	if take_shots: await shot("07_gameplay_goal_reached_gate_open")
	var gate: Node2D = sc.get_node("ExitGate")
	player.global_position = gate.global_position + Vector2(0, -20)
	await close_cards(sc)
	await until(func() -> bool: return quiz.visible)
	await answer(quiz, [0, 0, 0], take_shots)
	await wait(1.0)
	if take_shots: await shot("09_stage_clear_progress_saved")


func answer(quiz: Node, wrong: Array, shot_score: bool = false) -> void:
	var i := 0
	while is_instance_valid(quiz) and quiz.visible:
		if quiz._awaiting_start:
			quiz.start_questions()
		elif quiz._awaiting_continue:
			if shot_score: await shot("08_post_quiz_score")
			quiz._finish_quiz()
		elif not quiz._locked:
			var right: int = quiz._quiz.questions[quiz._index].correct_index
			var pick: int = right if wrong[mini(i, wrong.size() - 1)] == 0 else (right + 1) % quiz._order.size()
			quiz._on_choice(quiz._order.find(pick)); i += 1
		await wait(0.1)


func close_cards(sc: Node) -> void:
	var quiet := 0
	for t in 240:
		if not is_instance_valid(sc): return
		var card: Node = sc.find_child("FactCardPopup", true, false)
		if card and card.visible and card._can_close:
			card._close(); quiet = 0
		elif ld.is_idle() and not (card and card.visible):
			quiet += 1
			if quiet >= 6: return
		await create_timer(0.05, true).timeout


func until(cond: Callable, seconds: float = 10.0) -> void:
	var t := 0.0
	while not cond.call() and t < seconds:
		await create_timer(0.05, true).timeout; t += 0.05


func wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func physics(n: int) -> void:
	for i in n: await physics_frame


func shot(name: String) -> void:
	await process_frame; await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT).path_join(name + ".png"))
	print("shot ", name)
