extends SceneTree
## THE LAST FOREST — end-to-end smoke test (headless).
## Run:  godot --headless --path . -s res://tests/smoke_test.gd
## Plays Main Menu -> Login -> Stages 1..4 -> DB -> CSV and checks every fix.
## Prints PASS/FAIL lines and exits with code 1 if anything failed.
## It uses a throwaway DB file, so real pilot data is never touched.

var app: Node
var db: Node
var gs: Node
var ld: Node
var fails: int = 0
var passes: int = 0


func _initialize() -> void:
	await process_frame
	app = root.get_node("AppFlow")
	db = root.get_node("DatabaseManager")
	gs = root.get_node("GameState")
	ld = root.get_node("LearningDirector")
	_use_test_database()

	check("SQLite add-on loaded (not backup mode)", db.is_available())
	app.go_main_menu(); await frames(5)
	check("Main menu opens", current_scene.name == "MainMenu")

	check("Bad LRN rejected", app.login("12345", "Ana", "4-A") == "LOGIN_ERR_LRN")
	check("Valid LRN accepted", app.login("123456789012", "Ana", "4-Sampaguita") == "")
	await frames(5)
	check("Stage select shown", current_scene.name == "StageSelect")
	check("Stage 2 locked before Stage 1 is cleared", not app.is_stage_unlocked(2))

	for idx in range(1, 5):
		await play_stage(idx)

	var csv_path: String = db.export_eval_csv()
	var csv: String = FileAccess.get_file_as_string(csv_path)
	var rows: int = csv.strip_edges().split("\n").size() - 1
	check("CSV export has 4 stage rows", rows == 4, "rows=%d" % rows)
	check("CSV contains no LRN / name", not csv.contains("123456789012") and not csv.contains("Ana"))
	print("\n", csv)
	print("\n==== RESULT: %d passed, %d failed ====" % [passes, fails])
	quit(1 if fails > 0 else 0)


func play_stage(idx: int) -> void:
	print("\n----- STAGE %d -----" % idx)
	check("Stage %d unlocked" % idx, app.is_stage_unlocked(idx))
	app.start_stage(idx); await frames(6)
	var sc: Node = current_scene
	var ctl: Node = sc.get_node("StageController")
	var player: CharacterBody2D = sc.get_node("Player")
	check("Stage %d controller has player/spawn/gate" % idx, ctl.player != null and ctl.spawn_point != null and ctl.exit_gate != null)
	var tm: CanvasItem = sc.get_node("TileMapLayer")
	check("Stage %d burnt->green shader applied to tiles" % idx, tm.material is ShaderMaterial)

	# Pre-quiz: 3 questions, no score shown.
	var pre: Dictionary = await answer_quiz(sc, 0)
	check("Stage %d pre-quiz has 3 questions" % idx, pre.answered == 3, str(pre))
	check("Stage %d pre-quiz hides score" % idx, not pre.score_visible)
	await close_cards(sc)

	# Kill plane -> lose a heart and respawn at spawn.
	var hearts_before: int = gs.hearts
	player.global_position = Vector2(player.global_position.x, gs.current_stage.kill_y + 50)
	await physics(3)
	check("Stage %d fall: respawn + heart lost" % idx, player.global_position.distance_to(ctl.spawn_point.global_position) < 2.0 and gs.hearts == hearts_before - 1)
	await physics(160)  # wait out invulnerability

	gs.add_seeds(10)
	var zones: Array[Node] = get_nodes_in_group(&"planting_zones")
	if idx == 1:
		check("Stage 1 has 3 planting zones (goal 3)", zones.size() == 3 and gs.tree_goal == 3)
		await tutorial_sign_check(sc)

	# Real hold-E planting on the first zone (player must stay still).
	player.global_position = zones[0].global_position + Vector2(0, -12)
	await physics(40)
	Input.action_press(&"interact"); Input.action_press(&"move_right")
	await physics(240)
	Input.action_release(&"interact"); Input.action_release(&"move_right")
	await physics(5)
	check("Stage %d hold-E planted a tree" % idx, zones[0].sapling != null, "paused=%s owners=%s seeds=%d" % [paused, gs._pause_owners, gs.seeds])
	for z: Node in zones:
		if z.sapling == null:
			z.complete_interaction(null)

	var gate: Node = sc.get_node("ExitGate")
	if idx == 2:
		await physics(600)  # let the 3 pests attack
		var wilted: int = 0
		for s: Node in get_nodes_in_group(&"saplings"):
			if s.wilted: wilted += 1
		check("Stage 2 pests can wilt a sapling", wilted >= 1, "wilted=%d" % wilted)
		for p: Node in get_nodes_in_group(&"pests"):
			p.repel(p.global_position + Vector2(10, 0))
		grow_all()
		await physics(5)
		check("Stage 2 gate stays closed while a tree is wilted", wilted == 0 or not ctl.can_clear_stage())
		for s: Node in get_nodes_in_group(&"saplings"):
			if s.wilted: s.complete_interaction(null)
	if idx == 3:
		var gully: Node = sc.get_node("DryGully")
		grow_all()
		await physics(5)
		check("Stage 3 trees in dry soil can't grow before water", gs.trees_matured < gs.tree_goal)
		await physics(480)
		check("Stage 3 water wasted while lever points away", gully._absorbed == 0, "absorbed=%d" % gully._absorbed)
		var lever: Node = sc.get_node("Diverter")
		player.global_position = lever.global_position + Vector2(0, -12)
		await physics(30)
		Input.action_press(&"interact"); await physics(90); Input.action_release(&"interact")
		check("Stage 3 lever flipped with hold-E", lever.points_to_target)
		for i in 2400:
			await physics_frame
			if gully.is_hydrated(): break
		check("Stage 3 dry land gets watered", gully.is_hydrated(), "absorbed=%d/%d" % [gully._absorbed, gully.drops_needed])

	for k in 4:
		grow_all()
		await physics(2)
	check("Stage %d goal reached (%d/%d)" % [idx, gs.trees_matured, gs.tree_goal], gs.trees_matured >= gs.tree_goal)
	check("Stage %d gate opened" % idx, gate._ready_to_clear)
	await close_cards(sc)

	# Walk (not teleport) from the spawn point to the gate, like a child would.
	player.global_position = ctl.spawn_point.global_position
	await physics(10)
	var walked: bool = await walk_to(player, gate.global_position, ctl)
	check("Stage %d gate reachable on foot" % idx, walked or ctl._completed, "player at %s" % player.global_position)
	await physics(30)
	await close_cards(sc)
	var post: Dictionary = await answer_quiz(sc, 0)
	check("Stage %d post-quiz shows score" % idx, post.answered == 3 and post.score_visible, str(post))
	await frames(10)
	check("Stage %d -> Stage Clear, saved to DB" % idx, current_scene.name == "StageClear" and app.last_result.get("saved", false), str(app.last_result))
	check("Stage %d tips_viewed counts only fact cards" % idx, int(app.last_result.get("tips_viewed", -1)) >= 1)


func tutorial_sign_check(sc: Node) -> void:
	var tips_before: int = gs.tips_viewed
	var sign: Node = sc.get_node("TutorialSigns/Marker2")
	var player: CharacterBody2D = sc.get_node("Player")
	player.global_position = sign.global_position + Vector2(0, 10)
	await physics(20)
	var ev := InputEventAction.new(); ev.action = &"interact"; ev.pressed = true
	Input.parse_input_event(ev)
	await frames(4)
	var up := InputEventAction.new(); up.action = &"interact"; up.pressed = false
	Input.parse_input_event(up)
	await frames(2)
	var hud: Node = sc.get_node("HUDLayer/HUD")
	check("Tutorial sign opens translated hint", hud.is_climate_tip_open() and hud._climate_label.text.begins_with("Stand"), "open=%s label=%s ld_showing=%s owners=%s inside=%s planting=%s" % [hud.is_climate_tip_open(), hud._climate_label.text, ld.is_showing(), gs._pause_owners, sign._player_inside, player.state])
	await create_timer(1.4, true).timeout
	hud._dismiss_climate_tip()
	await frames(3)
	check("Hint closes and game resumes", not hud.is_climate_tip_open() and not paused)
	check("Hint not counted as a climate fact", gs.tips_viewed == tips_before)


# ------------------------------------------------------------------ helpers
func grow_all() -> void:
	for s: Node in get_nodes_in_group(&"saplings"):
		if is_instance_valid(s) and not s.wilted:
			s._growth = 999.0
			s._process(0.0)


func answer_quiz(sc: Node, right_choice: int) -> Dictionary:
	var quiz: Node = sc.find_child("QuizModal", true, false)
	for t in 160:  # up to 8 s real time
		if quiz != null and is_instance_valid(quiz) and quiz.visible: break
		await create_timer(0.05, true).timeout
	var res := {"answered": 0, "score_visible": false}
	if quiz == null or not quiz.visible:
		return res
	while is_instance_valid(quiz) and quiz.visible:
		if quiz._awaiting_continue:
			res.score_visible = quiz._score_tally.visible
			quiz._finish_quiz()
		elif not quiz._locked:
			quiz._on_choice(quiz._order.find(right_choice)); res.answered += 1
		await create_timer(0.1, true).timeout
	return res


## Closes every fact card that appears, waiting in REAL time (cards have a
## 1.5 s minimum reading time; headless frames are much faster than that).
func close_cards(sc: Node) -> void:
	var quiet: int = 0
	for t in 240:  # up to 12 s real time
		if not is_instance_valid(sc): return
		var card: Node = sc.find_child("FactCardPopup", true, false)
		if card and card.visible and card._can_close:
			card._close(); quiet = 0
		elif ld.is_idle() and not (card and card.visible):
			quiet += 1
			if quiet >= 6: return  # idle for 0.3 s
		await create_timer(0.05, true).timeout


func check(label: String, ok: bool, detail: String = "") -> void:
	if ok: passes += 1
	else: fails += 1
	print(("PASS  " if ok else "FAIL  ") + label + ("" if ok or detail == "" else "   [" + detail + "]"))


func frames(n: int) -> void:
	for i in n: await process_frame


func physics(n: int) -> void:
	for i in n: await physics_frame


func _use_test_database() -> void:
	# Close the real DB and reopen on a throwaway test file.
	db._close()
	db.set("_ready_ok", false)
	var test_path := "user://smoke_test.db"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	db.set_meta("test_db_path", test_path)
	db.init_db_at(test_path)


func walk_to(p: CharacterBody2D, target: Vector2, ctl: Node = null) -> bool:
	## Greedy walker: move toward target, jump/double-jump when blocked.
	var stuck := 0; var last_x := p.global_position.x
	for f in 1800:  # 15 s
		if ctl != null and ctl._completed:
			Input.action_release(&"move_left"); Input.action_release(&"move_right"); Input.action_release(&"jump")
			return true  # entered the open gate -> stage cleared
		if paused:
			var card = current_scene.find_child("FactCardPopup", true, false) if current_scene else null
			var cs = p.get_parent()
			card = cs.find_child("FactCardPopup", true, false)
			if card and card.visible and card._can_close: card._close()
			await create_timer(0.05, true).timeout
			continue
		var dx := target.x - p.global_position.x
		if absf(dx) < 20 and absf(target.y - p.global_position.y) < 70:
			Input.action_release(&"move_left"); Input.action_release(&"move_right"); Input.action_release(&"jump")
			return true
		Input.action_release(&"move_left"); Input.action_release(&"move_right")
		Input.action_press(&"move_right" if dx > 0 else &"move_left")
		if absf(p.global_position.x - last_x) < 0.5: stuck += 1
		else: stuck = 0
		last_x = p.global_position.x
		if (stuck > 10 or target.y < p.global_position.y - 60) and p.is_on_floor():
			Input.action_press(&"jump")
		elif not p.is_on_floor() and p.velocity.y > 0 and stuck > 10:
			Input.action_release(&"jump"); Input.action_press(&"jump")  # double jump
		else:
			Input.action_release(&"jump")
		await physics_frame
	Input.action_release(&"move_left"); Input.action_release(&"move_right"); Input.action_release(&"jump")
	return false
