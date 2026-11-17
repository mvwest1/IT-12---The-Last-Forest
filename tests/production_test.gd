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
