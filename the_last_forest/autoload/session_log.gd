extends Node
## SessionLog (Autoload #4, optional but strongly recommended for the capstone).
## Writes an anonymous CSV per play session to user://sessions/ so you have
## evidence for your evaluation chapter (time spent on cards, trees lost, etc.).
## On Windows: %APPDATA%\Godot\app_userdata\<project name>\sessions\
##
## Privacy: never store a child's name. Use a code the teacher assigns
## (e.g. "G4-A-07") via set_participant_code().

var participant_code: String = "anon"
var _file: FileAccess = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://sessions"))
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	_file = FileAccess.open("user://sessions/session_%s.csv" % stamp, FileAccess.WRITE)
	if _file == null:
		push_warning("SessionLog: could not open log file.")
		return
	_file.store_line("ms,participant,event,detail")
	_connect_bus()


func set_participant_code(code: String) -> void:
	participant_code = code.strip_edges().replace(",", "_")
	log_event("participant_set", participant_code)


func log_event(event_name: String, detail: String = "") -> void:
	if _file == null:
		return
	_file.store_line("%d,%s,%s,%s" % [Time.get_ticks_msec(), participant_code, event_name, detail.replace(",", ";")])
	_file.flush()


func _connect_bus() -> void:
	EventBus.stage_started.connect(func(id: StringName) -> void: log_event("stage_started", id))
	EventBus.stage_completed.connect(func(id: StringName) -> void: log_event("stage_completed", id))
	EventBus.tree_planted.connect(func(zone: Node2D, _s: Node2D) -> void: log_event("tree_planted", zone.name))
	EventBus.sapling_matured.connect(func(_s: Node2D) -> void: log_event("sapling_matured"))
	EventBus.sapling_wilted.connect(func(_s: Node2D) -> void: log_event("sapling_wilted"))
	EventBus.sapling_revived.connect(func(_s: Node2D) -> void: log_event("sapling_revived"))
	EventBus.interaction_denied.connect(func(_t: Node2D, reason: StringName) -> void: log_event("interaction_denied", reason))
	EventBus.player_defeated.connect(func() -> void: log_event("player_defeated"))
	EventBus.fact_card_opened.connect(func(id: StringName) -> void: log_event("fact_opened", id))
	EventBus.fact_card_closed.connect(func(id: StringName, secs: float) -> void: log_event("fact_closed", "%s:%.1fs" % [id, secs]))
