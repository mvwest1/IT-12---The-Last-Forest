@tool
extends EditorScript
## ONE-CLICK PROJECT SETUP for THE LAST FOREST.
## Open this file in the Script editor and press File → Run (Ctrl+Shift+X).
## Then restart the editor (Project → Reload Current Project).
##
## Why an EditorScript instead of hand-editing project.godot: the editor keeps
## its own copy of project.godot in memory and silently overwrites external
## edits. Running this INSIDE the editor makes the change stick.
##
## What it does (safe to run more than once):
##   1. Registers autoloads (keeps Music / EventBus / GameState / LearningDirector / SessionLog)
##      and adds DatabaseManager + AppFlow.
##   2. Removes shooter / split-screen inputs; adds "interact" (E, gamepad Y);
##      adds Space to "jump" (Space used to be "shoot").
##   3. Renames physics layers; adds "interactables", "pests", "water".
##   4. Adds the "restoration" global shader uniform.
##   5. Registers EN/FIL translations; sets the main scene to the Main Menu.

const AUTOLOADS: Array = [
	["EventBus", "res://the_last_forest/autoload/Events.gd"],
	["GameState", "res://the_last_forest/autoload/game_state.gd"],
	["LearningDirector", "res://the_last_forest/autoload/learning_director.gd"],
	["SessionLog", "res://the_last_forest/autoload/session_log.gd"],
	["DatabaseManager", "res://the_last_forest/autoload/database_manager.gd"],
	["AppFlow", "res://the_last_forest/autoload/app_flow.gd"],
]

const REMOVED_INPUTS: Array[String] = [
	"shoot", "shoot_p1", "shoot_p2", "jump_p1", "jump_p2",
	"move_left_p1", "move_left_p2", "move_right_p1", "move_right_p2", "splitscreen",
]

const TRANSLATIONS: Array[String] = [
	"res://the_last_forest/data/translations/facts.en.translation",
	"res://the_last_forest/data/translations/facts.fil.translation",
	"res://the_last_forest/data/translations/ui.en.translation",
	"res://the_last_forest/data/translations/ui.fil.translation",
]


func _run() -> void:
	# 1. Autoloads (order matters: EventBus first, AppFlow last).
	for entry: Array in AUTOLOADS:
		ProjectSettings.set_setting("autoload/" + entry[0], "*" + entry[1])
	# 2. Inputs.
	for action: String in REMOVED_INPUTS:
		if ProjectSettings.has_setting("input/" + action):
			ProjectSettings.clear("input/" + action)
	var e_key := InputEventKey.new()
	e_key.physical_keycode = KEY_E
	var pad_y := InputEventJoypadButton.new()
	pad_y.button_index = JOY_BUTTON_Y
	ProjectSettings.set_setting("input/interact", {"deadzone": 0.2, "events": [e_key, pad_y]})
	var jump: Dictionary = ProjectSettings.get_setting("input/jump", {"deadzone": 0.2, "events": []})
	var has_space: bool = false
	for ev: InputEvent in jump["events"]:
		if ev is InputEventKey and ((ev as InputEventKey).keycode == KEY_SPACE or (ev as InputEventKey).physical_keycode == KEY_SPACE):
			has_space = true
	if not has_space:
		var space := InputEventKey.new()
		space.physical_keycode = KEY_SPACE
		jump["events"].append(space)
		ProjectSettings.set_setting("input/jump", jump)
	# 3. Physics layer names.
	var layers: Dictionary = {
		1: "player", 2: "disabled_demo_enemies", 3: "disabled_demo_coins", 4: "platforms", 5: "ground",
		6: "Interactables", 7: "Pests", 8: "water",
	}
	for n: int in layers:
		ProjectSettings.set_setting("layer_names/2d_physics/layer_%d" % n, layers[n])
	# 4. Global shader uniform.
	ProjectSettings.set_setting("shader_globals/restoration", {"type": "float", "value": 0.0})
	if not RenderingServer.global_shader_parameter_get_list().has(&"restoration"):
		RenderingServer.global_shader_parameter_add(&"restoration", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	# 5. Translations + main scene.
	ProjectSettings.set_setting("internationalization/locale/translations", PackedStringArray(TRANSLATIONS))
	ProjectSettings.set_setting("application/run/main_scene", "res://the_last_forest/scenes/main_menu.tscn")
	ProjectSettings.set_setting("application/config/name", "THE LAST FOREST")
	var err: Error = ProjectSettings.save()
	print("THE LAST FOREST setup: ", "OK — now Project → Reload Current Project." if err == OK else "FAILED (%s)" % error_string(err))
