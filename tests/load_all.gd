extends SceneTree
func _initialize() -> void:
	await process_frame
	var bad := 0
	for f in _walk("res://the_last_forest"):
		var r = load(f)
		if r == null:
			print("FAIL load ", f); bad += 1; continue
		if r is PackedScene:
			var inst = (r as PackedScene).instantiate()
			if inst == null: print("FAIL instantiate ", f); bad += 1
			else: inst.free()
	print("LOAD CHECK DONE, failures=", bad, " locale=", TranslationServer.get_loaded_locales(), " tr=", tr("STAGE_1_TITLE"))
	quit()
func _walk(d: String) -> Array:
	var out := []
	for sub in DirAccess.get_directories_at(d): out += _walk(d + "/" + sub)
	for f in DirAccess.get_files_at(d):
		if f.get_extension() in ["gd", "tscn", "tres", "gdshader"]: out.append(d + "/" + f)
	return out
