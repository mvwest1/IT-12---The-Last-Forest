extends SceneTree
## v1.0.0 production features: schema v3 migration, Forest Points,
## leaderboard, persistent Leaf Journal, nickname cleaning, hashed teacher
## PIN, new screens and the Android Back button.
##   godot --headless --path . -s res://tests/production_test.gd

var passes: int = 0
var fails: int = 0
var app: Node
var db: Node


func check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		passes += 1
		print("  PASS  ", name)
	else:
		fails += 1
		print("  FAIL  ", name, "   ", detail)


func _initialize() -> void:
	await process_frame
	app = root.get_node("AppFlow")
	db = root.get_node("DatabaseManager")
	await migration_v2_to_v3()
	await scoring_and_leaderboard()
	await journal_persistence()
	nickname_cleaning()
	hashed_pin()
	await screens()
	await regressions()
	await bug_hunt()
	await flow_checks()
	print("\n==== PRODUCTION RESULT: %d passed, %d failed ====" % [passes, fails])
	db._close()
	quit(0 if fails == 0 else 1)


func fresh_db(file: String) -> void:
	db._close()
	db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
	db.init_db_at(file)


func frames(n: int) -> void:
	for i in n:
		await process_frame


# ------------------------------------------------------------------ Migration
func migration_v2_to_v3() -> void:
	print("\n-- Schema v2 -> v3 migration keeps old data and back-fills points")
	var path := "user://migration_test.db"
	db._close()
	db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var raw: Object = ClassDB.instantiate(&"SQLite")
	raw.path = path
	raw.open_db()
	for sql: String in [
		"CREATE TABLE students (student_id INTEGER PRIMARY KEY AUTOINCREMENT, lrn TEXT UNIQUE NOT NULL, name TEXT, grade_section TEXT, registered_at TEXT NOT NULL);",
		"CREATE TABLE quiz_results (quiz_id INTEGER PRIMARY KEY AUTOINCREMENT, attempt_id TEXT UNIQUE, student_id INTEGER NOT NULL, stage_index INTEGER NOT NULL, pre_score INTEGER, post_score INTEGER, timestamp TEXT NOT NULL);",
		"CREATE TABLE session_records (session_id INTEGER PRIMARY KEY AUTOINCREMENT, attempt_id TEXT UNIQUE, quiz_id INTEGER, student_id INTEGER NOT NULL, stage_index INTEGER NOT NULL, seeds_collected INTEGER NOT NULL DEFAULT 0, trees_matured INTEGER NOT NULL DEFAULT 0, completion_time REAL NOT NULL, tips_viewed INTEGER NOT NULL DEFAULT 0, completed_at TEXT NOT NULL);",
		"INSERT INTO students (lrn, name, grade_section, registered_at) VALUES ('h:abcd1234', '', '3-Rizal', '2026-10-01 08:00:00');",
		"INSERT INTO quiz_results (attempt_id, student_id, stage_index, pre_score, post_score, timestamp) VALUES ('att_old', 1, 1, 1, 3, '2026-10-01 08:10:00');",
		"INSERT INTO session_records (attempt_id, quiz_id, student_id, stage_index, seeds_collected, trees_matured, completion_time, tips_viewed, completed_at) VALUES ('att_old', 1, 1, 1, 5, 3, 100.0, 2, '2026-10-01 08:10:00');",
		"PRAGMA user_version = 2;",
	]:
		raw.query(sql)
	raw.close_db()
	db.init_db_at(path)
	check("v2 database opens after upgrade", db.is_available())
	check("students.nickname column added", db._has_column("students", "nickname"))
	check("session_records.score column added", db._has_column("session_records", "score"))
	check("journal_entries table created", db._exec("SELECT COUNT(*) AS n FROM journal_entries;"))
	db._exec("SELECT score FROM session_records WHERE attempt_id = 'att_old';")
	var expected: int = db.compute_score(3, 3, 2, 100.0)
	var got: int = int(db._db.query_result[0]["score"]) if db._db.query_result.size() > 0 else -1
	check("old attempt back-filled with the same formula (%d)" % expected, got == expected, "got=%d" % got)
	db._exec("PRAGMA user_version;")
	check("user_version bumped to 3", int(db._db.query_result[0]["user_version"]) == 3)


# ------------------------------------------------------------------ Points & leaderboard
func save_attempt(sid: int, stage: int, post: int, trees: int, tips: int, secs: float) -> void:
	var att: String = db.new_attempt_id(sid, stage)
	db.save_pre_quiz(sid, stage, 1, att)
	db.save_stage_completion(sid, stage, -1, post, 4, trees, secs, tips, att, 1)


func scoring_and_leaderboard() -> void:
	print("\n-- Forest Points and leaderboard")
	fresh_db("user://leaderboard_test.db")
	check("score formula: 3 correct, 3 trees, 2 facts, 100 s = 300+75+20+100",
			db.compute_score(3, 3, 2, 100.0) == 495)
	check("speed bonus never negative", db.compute_score(0, 0, 0, 9999.0) == 0)
	var a: int = db.register_student("111111111111", "", "4-Sampaguita")
	var b: int = db.register_student("222222222222", "", "4-Sampaguita")
	var c: int = db.register_student("333333333333", "", "4-Rosal")
	db.set_nickname(a, "Mika")
	save_attempt(a, 1, 3, 3, 2, 100.0)   # 495
	save_attempt(a, 1, 1, 3, 2, 100.0)   # worse replay: must not lower or double-count
	save_attempt(b, 1, 3, 3, 2, 100.0)   # 495 (tie with a)
	save_attempt(b, 2, 2, 4, 1, 200.0)   # 200+100+10+50 = 360
	save_attempt(c, 1, 2, 3, 1, 60.0)    # 200+75+10+120 = 405
	var lb: Array = db.get_leaderboard(10)
	check("one row per learner", lb.size() == 3, str(lb.size()))
	check("highest total first (B: 2 stages)", int(lb[0]["student_id"]) == b and int(lb[0]["total_points"]) == 855, str(lb[0]))
	check("best score per stage counts once (A = 495)", int(lb[1]["student_id"]) == a and int(lb[1]["total_points"]) == 495, str(lb[1]))
	check("nickname shown when set", str(lb[1]["display"]) == "Mika")
	check("Ranger code shown when no nickname", str(lb[0]["display"]).begins_with("Ranger #"))
	var leaks: bool = false
	for row: Dictionary in lb:
		for v: Variant in row.values():
			if str(v).contains("111111111111") or str(v).contains("h:"):
				leaks = true
	check("no LRN or LRN hash in leaderboard rows", not leaks)
	var cls: Array = db.get_leaderboard(10, "4-Rosal")
	check("class filter", cls.size() == 1 and int(cls[0]["student_id"]) == c)
	check("own rank lookup", int(db.get_leaderboard_entry(c)["rank"]) == 3)
	check("injection-shaped class filter is just text", db.get_leaderboard(10, "' OR 1=1 --").is_empty())
	var summary: Array = db.get_class_summary()
	check("teacher summary has a row per stage played", summary.size() == 2, str(summary))
	check("teacher summary avg gain (stage 2: 2-1 = +1)", is_equal_approx(float(summary[1]["avg_gain"]), 1.0), str(summary[1]))
	check("CSV export includes forest_points column", db.export_eval_csv().ends_with(".csv")
			and FileAccess.get_file_as_string(db.export_eval_csv()).contains("forest_points"))


# ------------------------------------------------------------------ Journal
func journal_persistence() -> void:
	print("\n-- Leaf Journal survives logging out")
	fresh_db("user://journal_test.db")
	var gs: Node = root.get_node("GameState")
	gs.unlocked_facts.clear()
	check("login ok", app.login("444444444444", "Lunti", "2-Mabini") == "")
	await frames(3)
	gs.unlock_fact(&"fact_forest_home")
	check("fact saved to journal_entries", "fact_forest_home" in db.get_journal(app.student_id))
	db.save_journal_entry(app.student_id, "fact_forest_home")
	check("duplicate unlock stored once", db.get_journal(app.student_id).size() == 1)
	var sid: int = app.student_id
	app.logout()
	await frames(3)
	gs.unlocked_facts.clear()
	app.login("444444444444", "", "2-Mabini")
	await frames(3)
	check("same learner after re-login", app.student_id == sid)
	check("journal restored from database", &"fact_forest_home" in app.journal_fact_ids())
	check("nickname kept from first login", app.nickname == "Lunti" and app.display_name() == "Lunti")
	check("learner code looks like #XXXX", app.learner_code.length() == 5 and app.learner_code.begins_with("#"))


# ------------------------------------------------------------------ Nicknames
func nickname_cleaning() -> void:
	print("\n-- Nickname cleaning")
	check("symbols removed", db.clean_nickname("<b>Ana</b>!") == "bAnab")
	check("max 12 characters", db.clean_nickname("Abcdefghijklmnop").length() == 12)
	check("SQL text is harmless", db.clean_nickname("x'); DROP TABLE students;--") == "x DROP TABLE")
	check("Filipino ñ allowed", db.clean_nickname("Niño") == "Niño")


# ------------------------------------------------------------------ PIN
func hashed_pin() -> void:
	print("\n-- Teacher PIN stored as a salted hash")
	LocalSettings.reload()
	var cfg: ConfigFile = LocalSettings.config()
	var old_plain: Variant = cfg.get_value("secrets", "teacher_pin", null)
	cfg.set_value("secrets", "teacher_pin", "")
	check("empty PIN means first-time setup", LocalSettings.needs_pin_setup())
	check("PIN must be 4-8 digits", not LocalSettings.is_valid_new_pin("12") and not LocalSettings.is_valid_new_pin("12ab")
			and LocalSettings.is_valid_new_pin("2468"))
	cfg.set_value("secrets", "teacher_pin_hash", LocalSettings._pin_hash("2468"))
	check("hash does not contain the PIN", not str(cfg.get_value("secrets", "teacher_pin_hash")).contains("2468"))
	check("correct PIN accepted against hash", LocalSettings.check_pin("2468"))
	check("wrong PIN rejected against hash", not LocalSettings.check_pin("2469") and not LocalSettings.check_pin(""))
	db.reset_pin_lockout()
	check("DatabaseManager uses the hashed PIN", db.verify_teacher_pin("2468"))
	LocalSettings.reload()  # back to the real file, untouched on disk
	check("real settings untouched", LocalSettings.value("teacher_pin") == str(old_plain if old_plain != null else ""))


# ------------------------------------------------------------------ Screens
func screens() -> void:
	print("\n-- New screens and Android Back button")
	fresh_db("user://screens_test.db")
	app.login("555555555555", "Kai", "4-Sampaguita")
	await frames(3)
	save_attempt(app.student_id, 1, 3, 3, 2, 90.0)
	app.goto(app.LEADERBOARD)
	await frames(4)
	check("leaderboard opens", current_scene.name == "Leaderboard")
	check("leaderboard lists the saved learner", current_scene._grid.get_child_count() >= 10, str(current_scene._grid.get_child_count()))
	root.go_back_requested.emit()
	await frames(4)
	check("Back on leaderboard -> main menu", current_scene.name == "MainMenu")
	var menu: Node = current_scene
	check("main menu shows the signed-in nickname", menu._badge.text.contains("Kai"), menu._badge.text)
	menu._on_teacher()
	await frames(2)
	root.go_back_requested.emit()
	await frames(3)
	check("Back closes the teacher panel first", current_scene == menu and not menu._teacher_panel.visible)
	app.goto(app.JOURNAL)
	await frames(4)
	check("Leaf Journal shows all fact tiles", current_scene._grid.get_child_count() == root.get_node("LearningDirector").get_all_facts().size())
	app.goto(app.SETTINGS)
	await frames(4)
	check("settings opens", current_scene.name == "SettingsScreen")
	var st: Node = root.get_node("Settings")
	var was_seen: bool = st.story_seen
	st.story_seen = false
	app.goto(app.STORY)
	await frames(4)
	check("story opens", current_scene.name == "StoryIntro")
	current_scene._finish()
	await frames(4)
	check("first story -> stage select for a signed-in learner", current_scene.name == "StageSelect")
	st.story_seen = was_seen
	st.save()
	check("bilingual lookup returns Filipino text", UiKit.tr_in("MENU_PLAY", "fil") == "Maglaro"
			and UiKit.tr_in("MENU_PLAY", "en") == "Play")
	app.logout()
	await frames(3)


# ------------------------------------------------------------------ Regressions
## Guards against problems found in the 2026-11-16 review of an outside
## agent's edits: fake leaderboard rows, real names stored, portrait lock.
func regressions() -> void:
	print("\n-- Regression guards")
	fresh_db("user://regress_test.db")
	check("empty database = empty leaderboard (no invented players)", db.get_leaderboard(10).is_empty())
	var sid: int = db.register_student("666666666666", "Juan Dela Cruz", "3-Rizal")
	db._exec_bind("SELECT COALESCE(name, '') AS n FROM students WHERE student_id = ?;", [sid])
	check("real name never written to students.name", str(db._db.query_result[0]["n"]) == "")
	check("game is locked to landscape (sensor landscape = 4)",
			int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 4)
	app.start_stage(1)
	await frames(30)
	var ui: CanvasLayer = current_scene.get_node("Player/UI")
	var gs: Node = root.get_node("GameState")
	gs.request_pause(&"test")
	await frames(3)
	check("touch buttons hidden while paused (quiz/cards/pause)", not ui.visible)
	gs.release_pause(&"test")
	gs.clear_pauses()
	await frames(3)
	check("touch buttons back after unpause", ui.visible)
	app.go_main_menu()
	await frames(4)


# ------------------------------------------------------------------ Bug hunt round (2026-11-17)
func bug_hunt() -> void:
	print("\n-- Bug hunt round")
	fresh_db("user://bughunt_test.db")
	var a: int = db.register_student("777777777771", "", "4-Sampaguita")
	var b: int = db.register_student("777777777772", "", "4-sampaguita ")
	db.set_nickname(a, "Mika"); db.set_nickname(b, "Mika")
	save_attempt(a, 1, 3, 3, 2, 100.0)
	save_attempt(b, 1, 2, 3, 2, 100.0)
	var cls: Array = db.get_leaderboard(10, "4-SAMPAGUITA")
	check("class filter ignores letter case and spaces", cls.size() == 2, str(cls.size()))
	check("same nickname twice is told apart by code", str(cls[0]["display"]) != str(cls[1]["display"])
			and str(cls[0]["display"]).begins_with("Mika #"), "%s / %s" % [cls[0]["display"], cls[1]["display"]])
	# Caterpillar really walks on the ground (does not silently turn into a beetle)
	app.login("777777777771", "", "4-Sampaguita")
	await frames(3)
	app.start_stage(2)
	await frames(40)
	root.get_node("GameState").clear_pauses()
	var cat: Node2D = current_scene.get_node_or_null("Pest2")
	var y0: float = cat.global_position.y if cat != null else 0.0
	await frames(60)
	check("Stage 2 caterpillar is a ground crawler", cat != null and bool(cat.get("crawler")))
	check("caterpillar stays on the ground while moving", cat != null and absf(cat.global_position.y - y0) < 1.0,
			"y0=%s y=%s" % [y0, cat.global_position.y if cat != null else -1.0])
	# Story replayed from Stage Select returns to Stage Select
	app.go_stage_select()
	await frames(4)
	app.story_return = app.STAGE_SELECT
	app.goto(app.STORY)
	await frames(4)
	current_scene._finish()
	await frames(4)
	check("story replay returns to where it was opened", current_scene.name == "StageSelect", current_scene.name)
	# Volume set on the Settings screen survives leaving it
	var st: Node = root.get_node("Settings")
	var old_v: float = st.music_volume
	app.goto(app.SETTINGS)
	await frames(4)
	st.set_music_volume(0.35)
	app.go_main_menu()
	await frames(4)
	var cfg := ConfigFile.new()
	cfg.load(st.PATH)
	check("music volume saved when leaving Settings", is_equal_approx(float(cfg.get_value("prefs", "music_volume", -1.0)), 0.35))
	st.set_music_volume(old_v)
	st.save()
	app.logout()
	await frames(3)


# ------------------------------------------------------------------ Flow (quiz + pause)
func flow_checks() -> void:
	print("\n-- Quiz and stage flow")
	fresh_db("user://flow_test.db")
	app.login("888888888881", "", "4-A")
	await frames(3)
	app.start_stage(1)
	var q: Node = null
	for i in 120:
		await process_frame
		q = current_scene.find_child("QuizModal", true, false) if current_scene else null
		if q != null and q.visible:
			break
	check("quiz opens on an intro page first", q != null and q._awaiting_start and not q._buttons[0].visible)
	q._on_choice(0)
	check("tapping before Start answers nothing", q._index == 0 and q._score == 0)
	q.start_questions()
	await create_timer(0.5, true).timeout
	check("answer buttons are never shown disabled", not q._buttons[0].disabled and not q._buttons[2].disabled)
	q._on_choice(0)
	check("tapped pre-test answer is highlighted", q._buttons[0].modulate.is_equal_approx(q.PICKED))
	check("pre-test shows no right/wrong", q._feedback.text == tr("QUIZ_THANKS"))
	for k in 2:
		await create_timer(1.2, true).timeout
		q._on_choice(1)
	await create_timer(1.0, true).timeout
	check("pre-test ends on a thank-you page without a score", q._awaiting_continue and not q._score_tally.visible)
	q._finish_quiz()
	await create_timer(0.3, true).timeout
	var ld: Node = root.get_node("LearningDirector")
	check("no fact card straight after the quiz (breather)", not ld.is_showing())
	var pause: Node = current_scene.find_child("PauseOverlay", true, false)
	await create_timer(3.5, true).timeout
	var card: Node = current_scene.find_child("FactCardPopup", true, false)
	for i in 60:
		if card.visible and card._can_close: break
		await create_timer(0.05, true).timeout
	if card.visible: card._close()
	await create_timer(0.4, true).timeout
	root.get_node("GameState").clear_pauses()
	pause.open()
	pause._on_stage_select()
	await frames(3)
	check("first tap on Stage Select only asks to confirm", current_scene.name != "StageSelect" and pause.visible)
	pause._on_stage_select()
	await frames(4)
	check("second tap leaves to Stage Select", current_scene.name == "StageSelect")
	app.logout()
	await frames(3)
