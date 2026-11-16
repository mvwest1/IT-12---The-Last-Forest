extends SceneTree
## Packaged-release smoke test (Activity 8 Part VI & Activity 10 Part VII).
## Verifies the exported .pck build outside the editor:
##   1. Application launches and MainMenu opens
##   2. Build version is displayed on MainMenu
##   3. SQLite GDExtension is connected
##   4. Learner login, pre-quiz save, transactional stage + post-quiz save, and My Records retrieval work
##   5. Application closes cleanly (exit code 0)

func _initialize() -> void:
	await process_frame
	var app: Node = root.get_node("AppFlow")
	var db: Node = root.get_node("DatabaseManager")
	db._close(); db.set("_ready_ok", false)
	var test_db := "user://release_smoke_test.db"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_db))
	db.init_db_at(test_db)

	app.go_main_menu()
	for i in range(6):
		await process_frame
	var menu: Node = current_scene
	var ok_launch: bool = menu != null and menu.name == "MainMenu"
	var ok_ver: bool = menu != null and menu._db_status.text.begins_with("v" + app.get_version())
	var ok_db: bool = db.is_available()
	var ok_login: bool = app.login("123456789012", "Ana", "4-Sampaguita") == ""
	for i in range(5):
		await process_frame
	app.record_pre_quiz(1, 2)
	var ok_save: bool = app.finish_stage({
		"stage_index": 1, "seeds_collected": 5, "trees_matured": 3,
		"duration": 64.2, "tips_viewed": 3, "pre_score": 2, "post_score": 3, "quiz_total": 3,
	})
	var recs: Array = db.get_student_records(app.student_id)
	var ok_retrieve: bool = recs.size() == 1 and int(recs[0].get("post_score", -1)) == 3 and app.is_stage_unlocked(2)
	print("RELEASE SMOKE TEST (v%s): launch=%s version_ui=%s sqlite=%s login=%s save=%s retrieve=%s" % [
		app.get_version(), ok_launch, ok_ver, ok_db, ok_login, ok_save, ok_retrieve])
	db._close()
	quit(0 if (ok_launch and ok_ver and ok_db and ok_login and ok_save and ok_retrieve) else 1)
