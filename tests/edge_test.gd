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
