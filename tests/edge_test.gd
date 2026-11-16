extends SceneTree
## THE LAST FOREST — edge cases the main smoke test does not cover.
## Run:  godot --headless --path . -s res://tests/edge_test.gd
## Uses a throwaway database, like smoke_test.gd.

var app: Node
var gs: Node
var ld: Node
var db: Node
var fails: int = 0
var passes: int = 0


func _initialize() -> void:
	await process_frame
	app = root.get_node("AppFlow"); gs = root.get_node("GameState")
	ld = root.get_node("LearningDirector"); db = root.get_node("DatabaseManager")
	db._close(); db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://edge_test.db"))
	db.init_db_at("user://edge_test.db")
	check("Login", app.login("123456789012", "Ana", "4-A") == "")
	await frames(5)

	await restoration_story()
	await defeat_and_respawn()
	await leave_mid_stage()
	await replay_resets_state()
	await hydration_swaps_bushes()
	await teacher_pin()
	await attempt_pairing_and_transactions()
	await no_raw_keys("fil")
	await no_raw_keys("en")
	print("\n==== EDGE RESULT: %d passed, %d failed ====" % [passes, fails])
	quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ cases
func restoration_story() -> void:
	print("\n-- Stage 1: burnt remains fade, green trees return")
	var sc: Node = await open_stage(1)
	check("Burnt snags visible at start", all_visible(&"vanish_at_2", true) and all_visible(&"vanish_at_4", true))
	check("Green trees hidden at start", all_visible(&"appear_at_2", false) and all_visible(&"appear_at_4", false))
	check("Smoke plumes present", sc.get_node("Smoke").get_child_count() >= 6)
	gs.add_seeds(10)
	for z: Node in get_nodes_in_group(&"planting_zones"):
		z.complete_interaction(null)
	for k in 4:
		grow_all(); await physics(2)
	await close_cards(sc)
	await create_timer(1.6, true).timeout  # fade tweens
	var leftovers := 0
	for t in range(1, 5):
		for n: Node in get_nodes_in_group(StringName("vanish_at_%d" % t)):
			if n is CanvasItem and (n as CanvasItem).visible: leftovers += 1
	check("All snags, stumps and smoke gone when the grove is restored", leftovers == 0, "still visible: %d" % leftovers)
	check("All green trees, flowers and ferns back", all_visible(&"appear_at_2", true) and all_visible(&"appear_at_3", true) and all_visible(&"appear_at_4", true))


func defeat_and_respawn() -> void:
	print("\n-- Losing all hearts")
	var sc: Node = current_scene
	var p: CharacterBody2D = sc.get_node("Player")
	var spawn: Vector2 = sc.get_node("SpawnPoint").global_position
	p.global_position = spawn + Vector2(600, 0)
	await physics(5)
	var trees_before: int = gs.trees_matured
	for i in gs.MAX_HEARTS:
		gs._invulnerable_until = 0
		gs.damage_player(1)
		await physics(2)
	check("Hearts refill after defeat", gs.hearts == gs.MAX_HEARTS, "hearts=%d" % gs.hearts)
	check("Player back at the checkpoint", p.global_position.distance_to(gs.checkpoint_position) < 4.0, "%s vs %s" % [p.global_position, gs.checkpoint_position])
	check("Grown trees are kept after defeat", gs.trees_matured == trees_before)


func leave_mid_stage() -> void:
	print("\n-- Leaving a stage halfway (Stage 3, water running)")
	var sc: Node = await open_stage(3)
	sc.get_node("Diverter").complete_interaction(null)
	await physics(60)
	gs.request_pause(&"test_menu")
	app.go_stage_select()
	await frames(6)
	check("Back on Stage Select", current_scene.name == "StageSelect")
	check("Game not left paused", not paused and gs._pause_owners.is_empty(), "owners=%s" % [gs._pause_owners])
	check("No water drops left behind", get_nodes_in_group(&"water_drops").is_empty())
	check("No fact cards queued", ld.is_idle())


func replay_resets_state() -> void:
	print("\n-- Replaying Stage 1")
	var sc: Node = await open_stage(1)
	check("Trees reset on replay", gs.trees_matured == 0 and gs.trees_planted == 0)
	check("Hearts full on replay", gs.hearts == gs.MAX_HEARTS)
	check("Checkpoint reset to the spawn point", gs.checkpoint_position.distance_to(sc.get_node("SpawnPoint").global_position) < 1.0)
	check("Gate closed on replay", not sc.get_node("ExitGate")._ready_to_clear)
	check("Burnt snags back on replay", all_visible(&"vanish_at_2", true))


func hydration_swaps_bushes() -> void:
	print("\n-- Stage 3: dry bushes turn green when the land is watered")
	var sc: Node = await open_stage(3)
	check("Straw bushes visible, green ones hidden", all_visible(&"dry_decor", true) and all_visible(&"wet_decor", false))
	var gully: Node = sc.get_node("DryGully")
	var lever: Node = sc.get_node("Diverter")
	lever.complete_interaction(null)
	for i in 2400:
		await physics_frame
		if gully.is_hydrated(): break
	await close_cards(sc)
	await create_timer(1.6, true).timeout
	check("Land watered", gully.is_hydrated())
	check("Straw bushes replaced by green ones", all_visible(&"dry_decor", false) and all_visible(&"wet_decor", true))


func teacher_pin() -> void:
	print("\n-- Teacher PIN & Security Controls (Activity 9)")
	db.reset_pin_lockout()
	var menu: Node = load(app.MAIN_MENU).instantiate()
	root.add_child(menu)
	await frames(3)
	check("Main menu displays build version", menu._db_status.text.begins_with("v" + app.get_version()), menu._db_status.text)
	var real: String = LocalSettings.value("teacher_pin")
	menu._pin.text = ""
	check("Empty PIN rejected", not menu._pin_ok())
	var wrong: String = "0000" if real != "0000" else "9999"
	menu._pin.text = wrong
	check("Wrong PIN rejected", not menu._pin_ok())
	check("Unauthorized teacher CSV export denied at DB layer", db.export_eval_csv_for_teacher(wrong) == "")
	menu._pin.text = real
	check("Correct PIN accepted (%s settings)" % ("sample" if LocalSettings.using_sample() else "local"), menu._pin_ok())
	# Brute-force lockout after 5 wrong PIN attempts
	for i in range(5):
		db.verify_teacher_pin(wrong)
	check("Teacher PIN locked out after 5 failed attempts", db.is_pin_locked_out() and not db.verify_teacher_pin(real))
	db.reset_pin_lockout()
	check("Teacher PIN works after lockout reset", db.verify_teacher_pin(real))
	# Negative security checks: invalid score bounds, cross-student tampering, CSV formula injection
	check("Negative or excessive quiz scores rejected (-500, 999)",
			db.save_pre_quiz(app.student_id, 1, -500) == -1 and db.save_pre_quiz(app.student_id, 1, 999) == -1)
	var qid_s1: int = db.save_pre_quiz(app.student_id, 1, 2)
	var intruding_student: int = db.register_student("999999999999", "Intruder", "4-B")
	check("Cross-student quiz overwrite denied",
			not db.save_post_quiz(qid_s1, intruding_student, 1, 0))
	check("CSV formula injection prefix neutralized",
			db._csv_cell("=HYPERLINK(\"http://evil\")").begins_with("\"'=HYPERLINK") or db._csv_cell("=SUM(A1)").begins_with("'=SUM"))
	menu.queue_free()
	await frames(2)


func attempt_pairing_and_transactions() -> void:
	print("\n-- Explicit attempt_id pairing, transactional save + Retry, and reopen persistence")
	# 1. Transactional save failure when save_post_quiz fails: no stage unlock, retained for Retry.
	gs.highest_completed_stage = 0
	app.current_stage_index = 1
	app.current_attempt_id = db.new_attempt_id(app.student_id, 1)
	app.record_pre_quiz(1, 1)
	db.simulate_post_quiz_failure = true
	var ok_fail_quiz: bool = app.finish_stage({
		"stage_index": 1, "seeds_collected": 4, "trees_matured": 3,
		"duration": 42.0, "tips_viewed": 2, "pre_score": 1, "post_score": 3, "quiz_total": 3,
	})
	await frames(4)
	check("Post-quiz failure makes finish_stage report unsaved", not ok_fail_quiz and not app.last_result.get("saved", true))
	check("Stage 2 stays locked when save fails", not app.is_stage_unlocked(2))
	check("Unsaved result retained for Retry", app.has_pending_save())
	check("Rollback prevented orphan session_records row", db.get_student_records(app.student_id).is_empty())
	db.simulate_post_quiz_failure = false

	# 2. Transactional save failure when save_stage_record fails: rolls back post_score update too.
	db.simulate_stage_record_failure = true
	var ok_fail_stage: bool = app.retry_save()
	check("Stage-record failure makes retry_save report unsaved", not ok_fail_stage and not app.last_result.get("saved", true))
	check("Stage 2 still locked after rolled-back retry", not app.is_stage_unlocked(2))
	db._exec_bind("SELECT post_score FROM quiz_results WHERE quiz_id = ?;", [app._pre_quiz_id])
	check("Transaction rolled back post_score update on stage_record failure",
			db._db.query_result.size() == 1 and db._db.query_result[0]["post_score"] == null,
			str(db._db.query_result))
	db.simulate_stage_record_failure = false

	# 3. Retry succeeds: both updates commit in one transaction and Stage 2 unlocks.
	var ok_retry: bool = app.retry_save()
	check("Retry succeeds once DB is healthy", ok_retry and app.last_result.get("saved", false) and not app.has_pending_save())
	check("Stage 2 unlocks after successful persistence", app.is_stage_unlocked(2))

	# 4. Repeated attempts on Stage 1 (even within the same second) keep distinct attempt_ids and scores.
	app.current_stage_index = 1
	app.current_attempt_id = db.new_attempt_id(app.student_id, 1)
	app.record_pre_quiz(1, 0)
	var ok_second: bool = app.finish_stage({
		"stage_index": 1, "seeds_collected": 6, "trees_matured": 3,
		"duration": 35.0, "tips_viewed": 3, "pre_score": 0, "post_score": 2, "quiz_total": 3,
	})
	await frames(4)
	check("Second Stage 1 attempt saved", ok_second)
	var recs: Array[Dictionary] = db.get_student_records(app.student_id)
	check("Two distinct Stage 1 attempts retrieved with distinct attempt_ids",
			recs.size() == 2 and str(recs[0].get("attempt_id", "")) != "" and recs[0].get("attempt_id") != recs[1].get("attempt_id"),
			str(recs))
	check("Newest attempt paired with its own quiz (0 -> 2) and first attempt paired with (1 -> 3)",
			int(recs[0].get("pre_score", -1)) == 0 and int(recs[0].get("post_score", -1)) == 2
			and int(recs[1].get("pre_score", -1)) == 1 and int(recs[1].get("post_score", -1)) == 3,
			str(recs))

	# 5. Simulate reopening the game: logout clears in-memory state, re-login restores from SQLite.
	var saved_student_id: int = app.student_id
	app.logout()
	await frames(4)
	check("Logout clears in-memory unlock state", gs.highest_completed_stage == 0 and not app.is_logged_in())
	check("Re-login with same LRN succeeds", app.login("123456789012", "Ana", "4-A") == "")
	await frames(4)
	check("Reopen restores same student_id, unlocked Stage 2, and saved quiz records",
			app.student_id == saved_student_id and app.is_stage_unlocked(2) and db.get_student_records(app.student_id).size() == 2)


func no_raw_keys(locale: String) -> void:
	print("\n-- No untranslated keys on screen (%s)" % locale)
	TranslationServer.set_locale(locale)
	var scenes := [app.MAIN_MENU, app.LOGIN, app.STAGE_SELECT, app.STAGE_CLEAR]
	for i in range(1, 5): scenes.append(app.STAGE_SCENES[i - 1])
	var bad: Array[String] = []
	for path: String in scenes:
		var inst: Node = load(path).instantiate()
		root.add_child(inst)
		await frames(3)
		_scan(inst, path.get_file(), bad)
		inst.queue_free()
		await frames(2)
		ld.clear_queue(); gs.clear_pauses()
	check("No raw translation keys (%s)" % locale, bad.is_empty(), ", ".join(bad.slice(0, 8)))
	# self-test: the detector must catch a key that has no translation
	var probe := Label.new(); probe.text = "ZZ_NOT_A_REAL_KEY"
	var caught: Array[String] = []
	_scan(probe, "probe", caught); probe.free()
	check("Raw-key detector works (%s)" % locale, caught.size() == 1)
	TranslationServer.set_locale("en")


func _scan(n: Node, where: String, bad: Array[String]) -> void:
	var texts: Array[String] = []
	if n is Label: texts.append((n as Label).text)
	elif n is Button: texts.append((n as Button).text)
	elif n is LineEdit: texts.append((n as LineEdit).placeholder_text)
	var re := RegEx.create_from_string("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$")
	for t in texts:
		if re.search(t) != null and TranslationServer.translate(t) == t:
			bad.append("%s:%s=%s" % [where, n.name, t])
	for c in n.get_children(): _scan(c, where, bad)


# ------------------------------------------------------------------ helpers
func open_stage(idx: int) -> Node:
	app.current_stage_index = 0
	app.start_stage(idx)
	await frames(6)
	var sc: Node = current_scene
	var q: Node = sc.find_child("QuizModal", true, false)
	for i in 80:
		if q.visible: break
		await create_timer(0.05, true).timeout
	q.hide(); q.finished.emit(0)
	await close_cards(sc)
	gs.clear_pauses()
	return sc


func all_visible(group: StringName, want: bool) -> bool:
	var nodes := get_nodes_in_group(group)
	if nodes.is_empty(): return false
	for n: Node in nodes:
		if n is CanvasItem and (n as CanvasItem).visible != want: return false
	return true


func grow_all() -> void:
	for s: Node in get_nodes_in_group(&"saplings"):
		if is_instance_valid(s) and not s.wilted:
			s._growth = 999.0
			s._process(0.0)


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


func check(label: String, ok: bool, detail: String = "") -> void:
	if ok: passes += 1
	else: fails += 1
	print(("PASS  " if ok else "FAIL  ") + label + ("" if ok or detail == "" else "   [" + detail + "]"))


func frames(n: int) -> void:
	for i in n: await process_frame


func physics(n: int) -> void:
	for i in n: await physics_frame
