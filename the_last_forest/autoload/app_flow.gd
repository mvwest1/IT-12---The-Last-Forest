extends Node
## AppFlow (Autoload) — screen routing + the logged-in student.
##
##   Main Menu -> LRN Login -> Stage Select -> Stage
##        (pre-quiz -> play -> facts -> post-quiz) -> DB write -> Stage Clear
##
## The database write happens BEFORE the Stage Clear screen appears, so a
## child closing the window on the celebration screen cannot lose the record.
## If a stage scene is launched directly from the editor (F6) nobody is
## logged in: the game still runs, and DB writes are skipped ("guest").

const MAIN_MENU: String = "res://the_last_forest/scenes/main_menu.tscn"
const LOGIN: String = "res://the_last_forest/ui/login.tscn"
const STAGE_SELECT: String = "res://the_last_forest/scenes/stage_select.tscn"
const STAGE_CLEAR: String = "res://the_last_forest/ui/stage_clear.tscn"
const STAGE_SCENES: Array[String] = [
	"res://the_last_forest/scenes/stage_1.tscn",
	"res://the_last_forest/scenes/stage_2.tscn",
	"res://the_last_forest/scenes/stage_3.tscn",
	"res://the_last_forest/scenes/stage_4.tscn",
]
const STAGE_TITLE_KEYS: Array[String] = ["STAGE_1_TITLE", "STAGE_2_TITLE", "STAGE_3_TITLE", "STAGE_4_TITLE"]
const STAGE_COUNT: int = 4

var student_id: int = -1
## Shown on screens/certificate; never written to the DB in pseudonymous mode.
var student_display_name: String = ""
var grade_section: String = ""
## 1..4 while a stage is running.
var current_stage_index: int = 0
## Result of the last cleared stage, read by the Stage Clear screen.
var last_result: Dictionary = {}

var _pre_quiz_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_fullscreen"):
		var mode := DisplayServer.window_get_mode()
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ Navigation
func goto(scene_path: String) -> void:
	LearningDirector.clear_queue()
	GameState.clear_pauses()
	get_tree().change_scene_to_file.call_deferred(scene_path)


func go_main_menu() -> void:
	goto(MAIN_MENU)


func go_login() -> void:
	goto(LOGIN)


func go_stage_select() -> void:
	goto(STAGE_SELECT)


# ------------------------------------------------------------------ Login
func is_logged_in() -> bool:
	return student_id > 0


## Returns "" on success, or a translation key describing the error.
func login(lrn: String, display_name: String, grade: String) -> String:
	if not DatabaseManager.is_valid_lrn(lrn.strip_edges()):
		return "LOGIN_ERR_LRN"
	if grade.strip_edges() == "":
		return "LOGIN_ERR_GRADE"
	var id: int = DatabaseManager.register_student(lrn, display_name, grade)
	if id < 0:
		return "LOGIN_ERR_DB"
	student_id = id
	student_display_name = display_name.strip_edges()
	grade_section = grade.strip_edges()
	GameState.highest_completed_stage = DatabaseManager.get_highest_completed_stage(id)
	go_stage_select()
	return ""


func logout() -> void:
	student_id = -1
	student_display_name = ""
	grade_section = ""
	GameState.highest_completed_stage = 0
	go_main_menu()


# ------------------------------------------------------------------ Stages
func stage_exists(index: int) -> bool:
	return index >= 1 and index <= STAGE_COUNT and ResourceLoader.exists(STAGE_SCENES[index - 1])


func is_stage_unlocked(index: int) -> bool:
	if index == 1:
		return true
	var highest: int = GameState.highest_completed_stage
	if is_logged_in():
		highest = maxi(highest, DatabaseManager.get_highest_completed_stage(student_id))
	return highest >= index - 1


func start_stage(index: int) -> void:
	if not stage_exists(index):
		push_warning("AppFlow: stage %d scene missing" % index)
		return
	current_stage_index = index
	_pre_quiz_id = -1
	goto(STAGE_SCENES[index - 1])


func has_next_stage() -> bool:
	return current_stage_index < STAGE_COUNT and stage_exists(current_stage_index + 1)


# ------------------------------------------------------------------ Research writes
func record_pre_quiz(stage_index: int, score: int) -> void:
	if not is_logged_in() or score < 0:
		return
	_pre_quiz_id = DatabaseManager.save_pre_quiz(student_id, stage_index, score)


## Called by StageController after the post-quiz. Writes, then shows Stage Clear.
## result keys: stage_index, seeds_collected, trees_matured, duration,
##              tips_viewed, pre_score, post_score, quiz_total
func finish_stage(result: Dictionary) -> void:
	GameState.record_stage_cleared(int(result.get("stage_index", 0)))
	var saved: bool = false
	if is_logged_in():
		if int(result.get("post_score", -1)) >= 0:
			DatabaseManager.save_post_quiz(_pre_quiz_id, student_id, result.stage_index, result.post_score)
		saved = DatabaseManager.save_stage_record(
				student_id, result.stage_index, result.seeds_collected,
				result.trees_matured, result.duration, result.tips_viewed)
	result["saved"] = saved
	result["guest"] = not is_logged_in()
	last_result = result
	goto(STAGE_CLEAR)
