extends SceneTree
## Can a child walk from spawn to every seed, zone and the exit gate?
## Greedy walker: move toward target x, jump when blocked. Reports unreachable targets.
func _initialize() -> void:
	for idx in range(1, 5):
		var sc: Node = load("res://the_last_forest/scenes/stage_%d.tscn" % idx).instantiate()
		root.add_child(sc)
		await process_frame
		var q = sc.find_child("QuizModal", true, false)
		for i in 60:
			if q.visible: break
			await create_timer(0.05, true).timeout
		q.hide(); q.finished.emit(0)
		root.get_node("LearningDirector").clear_queue()
		await create_timer(0.2, true).timeout
		var card = sc.find_child("FactCardPopup", true, false)
		for i in 60:
			if card.visible and card._can_close: card._close(); break
			await create_timer(0.05, true).timeout
		root.get_node("GameState").clear_pauses()
		var p: CharacterBody2D = sc.get_node("Player")
		var targets := []
		for n in sc.get_node("Seeds").get_children(): targets.append([n.name, n.global_position])
		for n in sc.get_node("PlantingZones").get_children(): targets.append([n.name, n.global_position])
		targets.append(["ExitGate", sc.get_node("ExitGate").global_position])
		targets.sort_custom(func(a, b): return a[1].x < b[1].x)
		var bad := []
		for t in targets:
			var ok := await walk_to(p, t[1])
			if not ok: bad.append("%s@%s (got %s)" % [t[0], t[1], Vector2i(p.global_position)])
		print("STAGE %d: %d targets, unreachable: %s" % [idx, targets.size(), bad])
		sc.queue_free(); await process_frame
		root.get_node("GameState").clear_pauses()
	quit()

func walk_to(p: CharacterBody2D, target: Vector2) -> bool:
	var stuck := 0; var last_x := p.global_position.x
	for f in 1800:  # 15 s
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
