extends SceneTree
## Activity 10 performance baseline + before/after optimization profiler.
## Run:
##   godot --headless --path . -s res://tests/perf_probe.gd
## or with a renderer:
##   godot --path . --rendering-driver opengl3 -s res://tests/perf_probe.gd

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	var db: Node = root.get_node("DatabaseManager")
	var app: Node = root.get_node("AppFlow")
	db._close(); db.set("_ready_ok", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://perf_test.db"))
	db.init_db_at("user://perf_test.db")
	app.login("123456789012", "Ana", "4-Sampaguita")
	await process_frame

	print("==== 1. STAGE RUNTIME & MEMORY BASELINE ====")
	for idx in range(1, 5):
		var t_load_start := Time.get_ticks_usec()
		var sc: Node = load("res://the_last_forest/scenes/stage_%d.tscn" % idx).instantiate()
		root.add_child(sc)
		await process_frame
		var load_ms := (Time.get_ticks_usec() - t_load_start) / 1000.0
		await create_timer(0.2, true).timeout
		root.get_node("LearningDirector").clear_queue()
		var q = sc.find_child("QuizModal", true, false)
		if q: q.hide()
		root.get_node("GameState").clear_pauses(); paused = false
		Input.action_press(&"move_right")
		var worst := 0.0; var total := 0.0; var n := 0
		var last := Time.get_ticks_usec()
		var end := last + 1_500_000
		while Time.get_ticks_usec() < end:
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1000.0
			last = now
			if n > 10: worst = maxf(worst, dt)
			total += dt; n += 1
		Input.action_release(&"move_right")
		var mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
		var peak_mb := OS.get_static_memory_peak_usage() / (1024.0 * 1024.0)
		print("STAGE %d: load %.2f ms | avg %.2f ms (%.0f fps) | worst %.2f ms | mem %.2f MB (peak %.2f MB) over %d frames" % [
			idx, load_ms, total / maxf(n, 1), 1000.0 / maxf(total / maxf(n, 1), 0.001), worst, mem_mb, peak_mb, n])
		sc.queue_free()
		await process_frame

	print("\n==== 2. DATABASE SAVE / RETRIEVE LATENCY ====")
	var t_save0 := Time.get_ticks_usec()
	var qid: int = db.save_pre_quiz(app.student_id, 1, 2)
	db.save_stage_completion(app.student_id, 1, qid, 3, 5, 3, 120.0, 2)
	var save_ms := (Time.get_ticks_usec() - t_save0) / 1000.0
	var t_ret0 := Time.get_ticks_usec()
	var recs: Array = db.get_student_records(app.student_id)
	var ret_ms := (Time.get_ticks_usec() - t_ret0) / 1000.0
	print("Transactional save (pre + post + stage): %.2f ms | Retrieve My Records (%d rows): %.2f ms" % [save_ms, recs.size(), ret_ms])

	print("\n==== 3. STAGE SELECT QUERY OPTIMIZATION (BEFORE vs AFTER) ====")
	# Before optimization: use_stage_cache = false (4 SQLite queries per StageSelect open)
	db.use_stage_cache = false
	db._highest_stage_cache.clear()
	var q_before_start: int = db.query_count
	var t_before0 := Time.get_ticks_usec()
	for iter in range(25):
		db.get_highest_completed_stage(app.student_id)
		for s in range(1, 5):
			app.is_stage_unlocked(s)
	var before_ms := (Time.get_ticks_usec() - t_before0) / 1000.0
	var queries_before: int = db.query_count - q_before_start

	# After optimization: use_stage_cache = true (1 SQLite query, then cached until next write)
	db.use_stage_cache = true
	db._highest_stage_cache.clear()
	var q_after_start: int = db.query_count
	var t_after0 := Time.get_ticks_usec()
	for iter in range(25):
		db.get_highest_completed_stage(app.student_id)
		for s in range(1, 5):
			app.is_stage_unlocked(s)
	var after_ms := (Time.get_ticks_usec() - t_after0) / 1000.0
	var queries_after: int = db.query_count - q_after_start
	print("25x StageSelect unlock checks — BEFORE (uncached): %d SQL queries in %.2f ms (%.3f ms/open)" % [queries_before, before_ms, before_ms / 25.0])
	print("25x StageSelect unlock checks — AFTER  (cached):   %d SQL query   in %.2f ms (%.3f ms/open)" % [queries_after, after_ms, after_ms / 25.0])
	quit()
