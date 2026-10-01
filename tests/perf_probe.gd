extends SceneTree
## Rough frame-rate probe: plays each stage for a few seconds with the player
## running right, and reports average and worst frame time.
## Run with a real renderer:  godot --path . --rendering-driver opengl3 -s res://tests/perf_probe.gd
## (On a software renderer this is a pessimistic number; real GPUs are faster.)

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	for idx in range(1, 5):
		var sc: Node = load("res://the_last_forest/scenes/stage_%d.tscn" % idx).instantiate()
		root.add_child(sc)
		await create_timer(0.3, true).timeout
		root.get_node("LearningDirector").clear_queue()
		var q = sc.find_child("QuizModal", true, false)
		if q: q.hide()
		root.get_node("GameState").clear_pauses(); paused = false
		Input.action_press(&"move_right")
		var worst := 0.0; var total := 0.0; var n := 0
		var last := Time.get_ticks_usec()
		var end := last + 4_000_000
		while Time.get_ticks_usec() < end:
			await process_frame
			var now := Time.get_ticks_usec()
			var dt := (now - last) / 1000.0
			last = now
			if n > 10: worst = maxf(worst, dt)
			total += dt; n += 1
		Input.action_release(&"move_right")
		print("STAGE %d: avg %.1f ms (%.0f fps), worst %.1f ms over %d frames" % [idx, total / n, 1000.0 / (total / n), worst, n])
		sc.queue_free()
		await process_frame
	quit()
