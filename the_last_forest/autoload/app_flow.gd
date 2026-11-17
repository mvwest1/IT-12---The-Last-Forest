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
const DEFAULT_VERSION: String = "1.0.0"
const STORY: String = "res://the_last_forest/ui/story_intro.tscn"
const LEADERBOARD: String = "res://the_last_forest/ui/leaderboard.tscn"
const JOURNAL: String = "res://the_last_forest/ui/leaf_journal.tscn"
const SETTINGS: String = "res://the_last_forest/ui/settings_screen.tscn"


func get_version() -> String:
	var v: String = str(ProjectSettings.get_setting("application/config/version", DEFAULT_VERSION)).strip_edges()
	return v if v != "" else DEFAULT_VERSION

var student_id: int = -1
## Shown on screens/certificate; never written to the DB in pseudonymous mode.
var student_display_name: String = ""
var grade_section: String = ""
## Public "#A9F2" code (from the salted LRN hash) and optional nickname,
## shown on the leaderboard instead of any real name.
var learner_code: String = ""
var nickname: String = ""
## 1..4 while a stage is running.
var current_stage_index: int = 0
## Explicit identifier linking the active attempt's pre/post quiz and gameplay record.
var current_attempt_id: String = ""
## Result of the last cleared stage, read by the Stage Clear screen.
var last_result: Dictionary = {}
## Screen to return to after the story is replayed (Settings or Stage Select).
var story_return: String = ""
## Retained stage result when a database save fails, so Retry can persist it.
var pending_result: Dictionary = {}

var _pre_quiz_id: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Every fact a logged-in learner unlocks is kept in their Leaf Journal.
	EventBus.climate_fact_unlocked.connect(_on_fact_unlocked)
	get_tree().root.go_back_requested.connect(_on_go_back)


## Android Back button / gesture: close an overlay or go up one screen,
## never quit the app by accident in the middle of a lesson.
func _on_go_back() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("handle_back") and bool(scene.call("handle_back")):
		return
	var pause := get_tree().get_first_node_in_group(&"pause_overlay")
	if pause != null and pause.has_method("handle_back"):
		pause.call("handle_back")
		return
	if scene == null:
		return
	var path: String = scene.scene_file_path
	if path == MAIN_MENU:
		return  # the main menu has its own Quit button
	if path == STAGE_CLEAR:
		go_stage_select()
	else:
		go_main_menu()


func _on_fact_unlocked(fact_id: StringName) -> void:
	if is_logged_in():
		DatabaseManager.save_journal_entry(student_id, String(fact_id))


## Facts for the Leaf Journal: everything saved for this learner plus
## anything unlocked this session (guest play).
func journal_fact_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if is_logged_in():
		for f: String in DatabaseManager.get_journal(student_id):
			ids.append(StringName(f))
	for f: StringName in GameState.unlocked_facts:
		if f not in ids:
			ids.append(f)
	return ids


func display_name() -> String:
	if nickname != "":
		return nickname
	return ("Ranger " + learner_code) if learner_code != "" else "Ranger"


func set_nickname(nick: String) -> void:
	nickname = DatabaseManager.clean_nickname(nick)
	if is_logged_in():
		DatabaseManager.set_nickname(student_id, nickname)


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
	learner_code = DatabaseManager.get_learner_code(id)
	nickname = DatabaseManager.get_nickname(id)
	# The "name" box is now an optional leaderboard nickname.
	if DatabaseManager.clean_nickname(display_name) != "":
		set_nickname(display_name)
	GameState.highest_completed_stage = DatabaseManager.get_highest_completed_stage(id)
	go_stage_select()
	return ""


func logout() -> void:
	student_id = -1
	student_display_name = ""
	grade_section = ""
	learner_code = ""
	nickname = ""
	current_attempt_id = ""
	_pre_quiz_id = -1
	pending_result = {}
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
	current_attempt_id = DatabaseManager.new_attempt_id(student_id, index)
	pending_result = {}
	goto(STAGE_SCENES[index - 1])


func has_next_stage() -> bool:
	return current_stage_index < STAGE_COUNT and stage_exists(current_stage_index + 1)


# ------------------------------------------------------------------ Research writes
func record_pre_quiz(stage_index: int, score: int) -> void:
	if current_attempt_id == "":
		current_attempt_id = DatabaseManager.new_attempt_id(student_id, stage_index)
	if not is_logged_in() or score < 0:
		return
	_pre_quiz_id = DatabaseManager.save_pre_quiz(student_id, stage_index, score, current_attempt_id)


## Called by StageController after the post-quiz. Saves both the post-quiz
## score and the stage record inside a single transaction, confirms both
## succeed before unlocking the next stage, and retains the result for Retry
## if either write fails.
## result keys: stage_index, seeds_collected, trees_matured, duration,
##              tips_viewed, pre_score, post_score, quiz_total
func finish_stage(result: Dictionary) -> bool:
	var attempt_result: Dictionary = result.duplicate(true)
	var stage_idx: int = int(attempt_result.get("stage_index", current_stage_index))
	attempt_result["stage_index"] = stage_idx
	if str(attempt_result.get("attempt_id", "")) == "":
		if current_attempt_id == "":
			current_attempt_id = DatabaseManager.new_attempt_id(student_id, stage_idx)
		attempt_result["attempt_id"] = current_attempt_id
	if int(attempt_result.get("quiz_id", -1)) <= 0 and _pre_quiz_id > 0:
		attempt_result["quiz_id"] = _pre_quiz_id
	attempt_result["score"] = DatabaseManager.compute_score(
			int(attempt_result.get("post_score", 0)), int(attempt_result.get("trees_matured", 0)),
			int(attempt_result.get("tips_viewed", 0)), float(attempt_result.get("duration", 0.0)))
	var previous_best: int = DatabaseManager.get_best_stage_score(student_id, stage_idx) if is_logged_in() else 0
	var saved: bool = _persist_stage_result(attempt_result)
	attempt_result["saved"] = saved
	attempt_result["previous_best"] = previous_best
	attempt_result["guest"] = not is_logged_in()
	last_result = attempt_result
	if saved:
		pending_result = {}
		GameState.record_stage_cleared(stage_idx)
		current_attempt_id = ""
	elif not is_logged_in():
		pending_result = {}
		GameState.record_stage_cleared(stage_idx)
		current_attempt_id = ""
	else:
		pending_result = attempt_result.duplicate(true)
	goto(STAGE_CLEAR)
	return saved


func has_pending_save() -> bool:
	return not pending_result.is_empty()


## Retries saving the retained result from a failed finish_stage() call.
## Unlocks the next stage only after persistence succeeds.
func retry_save() -> bool:
	var target: Dictionary = pending_result if not pending_result.is_empty() else last_result
	if target.is_empty() or not is_logged_in():
		return false
	var saved: bool = _persist_stage_result(target)
	target["saved"] = saved
	target["guest"] = false
	last_result = target.duplicate(true)
	if saved:
		var stage_idx: int = int(target.get("stage_index", current_stage_index))
		pending_result = {}
		current_attempt_id = ""
		GameState.record_stage_cleared(stage_idx)
	else:
		pending_result = target.duplicate(true)
	return saved


func _persist_stage_result(attempt_result: Dictionary) -> bool:
	if not is_logged_in():
		return false
	var stage_idx: int = int(attempt_result.get("stage_index", current_stage_index))
	var post_score: int = int(attempt_result.get("post_score", -1))
	if post_score < 0:
		return false
	var pre_raw: int = int(attempt_result.get("pre_score", -1))
	var pre_score: Variant = pre_raw if pre_raw >= 0 else null
	var quiz_id: int = int(attempt_result.get("quiz_id", _pre_quiz_id))
	var attempt_id: String = str(attempt_result.get("attempt_id", current_attempt_id)).strip_edges()
	if attempt_id == "":
		attempt_id = DatabaseManager.new_attempt_id(student_id, stage_idx)
		current_attempt_id = attempt_id
		attempt_result["attempt_id"] = attempt_id
	if not DatabaseManager.begin_transaction():
		return false
	var quiz_ok: bool = DatabaseManager.save_post_quiz(
			quiz_id, student_id, stage_idx, post_score, attempt_id, pre_score)
	if quiz_ok and quiz_id <= 0 and DatabaseManager.last_saved_quiz_id > 0:
		quiz_id = DatabaseManager.last_saved_quiz_id
		_pre_quiz_id = quiz_id
		attempt_result["quiz_id"] = quiz_id
	var stage_ok: bool = quiz_ok and DatabaseManager.save_stage_record(
			student_id, stage_idx,
			int(attempt_result.get("seeds_collected", 0)),
			int(attempt_result.get("trees_matured", 0)),
			float(attempt_result.get("duration", 0.0)),
			int(attempt_result.get("tips_viewed", 0)),
			attempt_id, quiz_id, int(attempt_result.get("score", 0)))
	if quiz_ok and stage_ok and DatabaseManager.commit_transaction():
		return true
	DatabaseManager.rollback_transaction()
	return false
