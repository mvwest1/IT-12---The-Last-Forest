extends Node
## DatabaseManager (Autoload) — offline evaluation store (godot-sqlite GDExtension).
##
## Install: AssetLib → "Godot SQLite" (2shady4u) → Install → restart editor.
## Export for Windows: the addon's .gdextension already lists the Windows x86_64
## library; lab PCs must be 64-bit Windows.
##
## If the extension is missing, NOTHING crashes: every write goes to
## user://eval_fallback.jsonl instead, so a pilot session is never lost.
##
## PRIVACY (Data Privacy Act of 2012 / RA 10173). The LRN and full name of
## a minor are personal information. Default mode is PSEUDONYMOUS:
##   * `lrn` column stores "h:" + SHA-256(salt + LRN), not the raw LRN.
##   * `name` column stays empty (the display name lives in memory only).
## Set STORE_IDENTIFIERS_IN_CLEAR = true ONLY if your adviser and the school
## explicitly require raw identifiers (and you have written consent).
## This is pseudonymisation, not anonymisation: whoever holds the salt and a
## class list can re-identify students. Keep the salt out of your manuscript.

const DB_PATH: String = "user://the_last_forest_eval.db"
const FALLBACK_PATH: String = "user://eval_fallback.jsonl"
const EXPORT_DIR: String = "user://exports"
const SCHEMA_VERSION: int = 1

const STORE_IDENTIFIERS_IN_CLEAR: bool = false
## Change before the pilot; identical on every lab PC so the same LRN maps to
## the same student_id across machines.
const LRN_SALT: String = "CHANGE-ME-santa-rosa-central-2-2026"

# ------------------------------------------------------------------ DDL
const DDL: Array[String] = [
	"""CREATE TABLE IF NOT EXISTS students (
		student_id    INTEGER PRIMARY KEY AUTOINCREMENT,
		lrn           TEXT UNIQUE NOT NULL,
		name          TEXT,
		grade_section TEXT,
		registered_at TEXT NOT NULL
	);""",
	"""CREATE TABLE IF NOT EXISTS session_records (
		session_id      INTEGER PRIMARY KEY AUTOINCREMENT,
		student_id      INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
		stage_index     INTEGER NOT NULL CHECK (stage_index BETWEEN 1 AND 4),
		seeds_collected INTEGER NOT NULL DEFAULT 0 CHECK (seeds_collected >= 0),
		trees_matured   INTEGER NOT NULL DEFAULT 0 CHECK (trees_matured >= 0),
		completion_time REAL    NOT NULL CHECK (completion_time >= 0),
		tips_viewed     INTEGER NOT NULL DEFAULT 0 CHECK (tips_viewed >= 0),
		completed_at    TEXT    NOT NULL
	);""",
	"""CREATE TABLE IF NOT EXISTS quiz_results (
		quiz_id     INTEGER PRIMARY KEY AUTOINCREMENT,
		student_id  INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
		stage_index INTEGER NOT NULL CHECK (stage_index BETWEEN 1 AND 4),
		pre_score   INTEGER CHECK (pre_score  IS NULL OR pre_score  >= 0),
		post_score  INTEGER CHECK (post_score IS NULL OR post_score >= 0),
		timestamp   TEXT    NOT NULL
	);""",
	"CREATE INDEX IF NOT EXISTS idx_session_student_stage ON session_records(student_id, stage_index);",
	"CREATE INDEX IF NOT EXISTS idx_quiz_student_stage ON quiz_results(student_id, stage_index, timestamp);",
]

## One row per completed stage attempt, paired with the quiz attempt that
## started most recently before that completion (schema has no session_id FK
## on quiz_results, so pairing is by student + stage + time).
const EXPORT_SQL: String = """
SELECT s.student_id,
       s.grade_section,
       r.session_id,
       r.stage_index,
       q.pre_score,
       q.post_score,
       (q.post_score - q.pre_score)  AS score_gain,
       r.seeds_collected,
       r.trees_matured,
       ROUND(r.completion_time, 1)   AS completion_time_sec,
       r.tips_viewed,
       r.completed_at
FROM session_records r
JOIN students s ON s.student_id = r.student_id
LEFT JOIN quiz_results q ON q.quiz_id = (
    SELECT q2.quiz_id FROM quiz_results q2
    WHERE q2.student_id = r.student_id
      AND q2.stage_index = r.stage_index
      AND q2.timestamp <= r.completed_at
    ORDER BY q2.timestamp DESC, q2.quiz_id DESC
    LIMIT 1)
ORDER BY s.student_id, r.stage_index, r.completed_at;
"""

const EXPORT_COLUMNS: Array[String] = [
	"student_id", "grade_section", "session_id", "stage_index", "pre_score",
	"post_score", "score_gain", "seeds_collected", "trees_matured",
	"completion_time_sec", "tips_viewed", "completed_at",
]

## Optional injection point for tests (an object with the godot-sqlite API).
var backend_override: Variant = null

var _db: Variant = null
var _ready_ok: bool = false


func _ready() -> void:
	init_db()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close()


# ================================================================== Core API
func init_db() -> void:
	if _ready_ok:
		return
	_db = backend_override if backend_override != null else _create_backend()
	if _db == null:
		push_warning("DatabaseManager: godot-sqlite not installed — using JSONL fallback at " + FALLBACK_PATH)
		return
	_db.path = DB_PATH
	_db.foreign_keys = true
	_db.verbosity_level = 0  # QUIET
	if not _db.open_db():
		push_error("DatabaseManager: could not open " + DB_PATH + " — " + str(_db.error_message))
		_db = null
		return
	_exec("PRAGMA journal_mode = WAL;")   # safer if the PC is switched off mid-write
	for statement: String in DDL:
		if not _exec(statement):
			push_error("DatabaseManager: DDL failed — " + str(_db.error_message))
			return
	_exec("PRAGMA user_version = %d;" % SCHEMA_VERSION)
	_ready_ok = true


func is_available() -> bool:
	return _ready_ok


## Returns the student_id (existing one if this LRN is already registered),
## or -1 on failure. LRN must be the 12-digit DepEd Learner Reference Number.
func register_student(lrn: String, name: String, grade_section: String) -> int:
	var clean_lrn: String = lrn.strip_edges()
	if not is_valid_lrn(clean_lrn):
		return -1
	var key: String = _lrn_key(clean_lrn)
	var stored_name: String = name.strip_edges() if STORE_IDENTIFIERS_IN_CLEAR else ""
	var grade: String = grade_section.strip_edges()
	if not _ready_ok:
		return _fallback_register(key, grade)
	_exec_bind(
		"INSERT OR IGNORE INTO students (lrn, name, grade_section, registered_at) VALUES (?, ?, ?, ?);",
		[key, stored_name, grade, _now()])
	# Keep grade/section current if the student was registered before.
	_exec_bind("UPDATE students SET grade_section = ? WHERE lrn = ?;", [grade, key])
	if not _exec_bind("SELECT student_id FROM students WHERE lrn = ?;", [key]):
		return -1
	var rows: Array = _db.query_result
	return int(rows[0]["student_id"]) if rows.size() > 0 else -1


func save_stage_record(student_id: int, stage_idx: int, seeds: int, trees: int, duration: float, tips: int) -> bool:
	var row: Dictionary = {
		"student_id": student_id, "stage_index": stage_idx, "seeds_collected": maxi(seeds, 0),
		"trees_matured": maxi(trees, 0), "completion_time": maxf(duration, 0.0),
		"tips_viewed": maxi(tips, 0), "completed_at": _now(),
	}
	if not _ready_ok:
		return _fallback_write("session_records", row)
	return _exec_bind(
		"INSERT INTO session_records (student_id, stage_index, seeds_collected, trees_matured, completion_time, tips_viewed, completed_at) VALUES (?, ?, ?, ?, ?, ?, ?);",
		[row.student_id, row.stage_index, row.seeds_collected, row.trees_matured, row.completion_time, row.tips_viewed, row.completed_at])


## Pre-test: creates the quiz row. Returns quiz_id (or -1).
func save_pre_quiz(student_id: int, stage_idx: int, pre_score: int) -> int:
	var ts: String = _now()
	if not _ready_ok:
		_fallback_write("quiz_results", {"student_id": student_id, "stage_index": stage_idx, "pre_score": pre_score, "timestamp": ts})
		return -1
	if not _exec_bind(
			"INSERT INTO quiz_results (student_id, stage_index, pre_score, post_score, timestamp) VALUES (?, ?, ?, NULL, ?);",
			[student_id, stage_idx, pre_score, ts]):
		return -1
	return int(_db.last_insert_rowid)


## Post-test: fills post_score on the row created by save_pre_quiz. If the
## pre row is missing (quiz_id < 0), a row with NULL pre_score is inserted.
func save_post_quiz(quiz_id: int, student_id: int, stage_idx: int, post_score: int) -> bool:
	if not _ready_ok:
		return _fallback_write("quiz_results", {"quiz_id": quiz_id, "student_id": student_id, "stage_index": stage_idx, "post_score": post_score, "timestamp": _now()})
	if quiz_id > 0:
		return _exec_bind("UPDATE quiz_results SET post_score = ? WHERE quiz_id = ?;", [post_score, quiz_id])
	return _exec_bind(
		"INSERT INTO quiz_results (student_id, stage_index, pre_score, post_score, timestamp) VALUES (?, ?, NULL, ?, ?);",
		[student_id, stage_idx, post_score, _now()])


## Highest stage index this student has cleared (0 = none). Drives unlocks.
func get_highest_completed_stage(student_id: int) -> int:
	if student_id < 0:
		return 0
	if not _ready_ok:
		return _fallback_highest_completed_stage(student_id)
	if not _exec_bind("SELECT COALESCE(MAX(stage_index), 0) AS best FROM session_records WHERE student_id = ?;", [student_id]):
		return 0
	var rows: Array = _db.query_result
	return int(rows[0]["best"]) if rows.size() > 0 else 0


## Writes user://exports/eval_<timestamp>.csv and returns its absolute OS path
## ("" on failure). Contains NO names and NO LRNs — student_id only.
func export_eval_csv() -> String:
	if not _ready_ok:
		return _export_fallback_csv()
	if not _exec(EXPORT_SQL):
		return ""
	var rows: Array = _db.query_result
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	var stamp: String = _now().replace(":", "-").replace(" ", "_")
	var res_path: String = "%s/eval_%s.csv" % [EXPORT_DIR, stamp]
	var file := FileAccess.open(res_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("﻿")  # UTF-8 BOM so Excel shows Filipino characters correctly
	file.store_line(",".join(EXPORT_COLUMNS))
	for row: Dictionary in rows:
		var cells: PackedStringArray = []
		for col: String in EXPORT_COLUMNS:
			cells.append(_csv_cell(row.get(col)))
		file.store_line(",".join(cells))
	file.close()
	return ProjectSettings.globalize_path(res_path)


## Exports the fallback journal with the same safe columns as the SQLite query.
## Student names and LRNs are never written to this CSV.
func _export_fallback_csv() -> String:
	var students: Dictionary = {}
	var quizzes: Array[Dictionary] = []
	var records: Array[Dictionary] = []
	if FileAccess.file_exists(FALLBACK_PATH):
		var input := FileAccess.open(FALLBACK_PATH, FileAccess.READ)
		if input == null:
			return ""
		while not input.eof_reached():
			var parsed: Variant = JSON.parse_string(input.get_line())
			if not (parsed is Dictionary):
				continue
			var entry: Dictionary = parsed
			match str(entry.get("table", "")):
				"students":
					students[int(entry.get("student_id", -1))] = entry
				"quiz_results":
					quizzes.append(entry)
				"session_records":
					records.append(entry)
		input.close()
	var out_dir: String = ProjectSettings.globalize_path(EXPORT_DIR)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var stamp: String = _now().replace(":", "-").replace(" ", "_")
	var res_path: String = "%s/eval_%s.csv" % [EXPORT_DIR, stamp]
	var file := FileAccess.open(res_path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("\uFEFF")
	file.store_line(",".join(EXPORT_COLUMNS))
	for record: Dictionary in records:
		var pre_quiz: Dictionary = {}
		var post_quiz: Dictionary = {}
		for quiz: Dictionary in quizzes:
			if int(quiz.get("student_id", -1)) != int(record.get("student_id", -2)):
				continue
			if int(quiz.get("stage_index", 0)) != int(record.get("stage_index", 0)):
				continue
			if str(quiz.get("timestamp", "")) > str(record.get("completed_at", "")):
				continue
			if quiz.has("pre_score") and str(quiz.get("timestamp", "")) >= str(pre_quiz.get("timestamp", "")):
				pre_quiz = quiz
			if quiz.has("post_score") and str(quiz.get("timestamp", "")) >= str(post_quiz.get("timestamp", "")):
				post_quiz = quiz
		var student: Dictionary = students.get(int(record.get("student_id", -1)), {})
		var row: Dictionary = {
			"student_id": record.get("student_id"),
			"grade_section": record.get("grade_section", student.get("grade_section", "")),
			"session_id": record.get("session_id", ""),
			"stage_index": record.get("stage_index", ""),
			"pre_score": pre_quiz.get("pre_score"),
			"post_score": post_quiz.get("post_score"),
			"score_gain": int(post_quiz.get("post_score", 0)) - int(pre_quiz.get("pre_score", 0)) if post_quiz.has("post_score") and pre_quiz.has("pre_score") else null,
			"seeds_collected": record.get("seeds_collected", 0),
			"trees_matured": record.get("trees_matured", 0),
			"completion_time_sec": snappedf(float(record.get("completion_time", 0.0)), 0.1),
			"tips_viewed": record.get("tips_viewed", 0),
			"completed_at": record.get("completed_at", ""),
		}
		var cells: PackedStringArray = []
		for column: String in EXPORT_COLUMNS:
			cells.append(_csv_cell(row.get(column)))
		file.store_line(",".join(cells))
	file.close()
	return ProjectSettings.globalize_path(res_path)


# ================================================================== Helpers
static func is_valid_lrn(lrn: String) -> bool:
	var re := RegEx.create_from_string("^\\d{12}$")
	return re.search(lrn) != null


func _lrn_key(lrn: String) -> String:
	if STORE_IDENTIFIERS_IN_CLEAR:
		return lrn
	return "h:" + (LRN_SALT + lrn).sha256_text()


func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)  # "YYYY-MM-DD HH:MM:SS" local


func _create_backend() -> Variant:
	if ClassDB.class_exists(&"SQLite"):
		return ClassDB.instantiate(&"SQLite")
	return null


func _exec(sql: String) -> bool:
	if _db == null:
		return false
	var ok: bool = _db.query(sql)
	if not ok:
		push_error("SQL failed: %s\n%s" % [str(_db.error_message), sql])
	return ok


func _exec_bind(sql: String, bindings: Array) -> bool:
	if _db == null:
		return false
	var ok: bool = _db.query_with_bindings(sql, bindings)
	if not ok:
		push_error("SQL failed: %s\n%s" % [str(_db.error_message), sql])
	return ok


func _close() -> void:
	if _db != null and _ready_ok:
		_db.close_db()
	_ready_ok = false


static func _csv_cell(value: Variant) -> String:
	if value == null:
		return ""
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1e15:
		value = int(value)  # SQLite INTEGER columns may arrive as float
	var text: String = str(value)
	if text.contains(",") or text.contains("\"") or text.contains("\n"):
		return "\"" + text.replace("\"", "\"\"") + "\""
	return text


func _fallback_highest_completed_stage(student_id: int) -> int:
	if not FileAccess.file_exists(FALLBACK_PATH):
		return 0
	var file := FileAccess.open(FALLBACK_PATH, FileAccess.READ)
	if file == null:
		return 0
	var highest: int = 0
	while not file.eof_reached():
		var parsed: Variant = JSON.parse_string(file.get_line())
		if parsed is Dictionary:
			var entry: Dictionary = parsed
			if str(entry.get("table", "")) == "session_records" and int(entry.get("student_id", -1)) == student_id:
				highest = maxi(highest, int(entry.get("stage_index", 0)))
	file.close()
	return highest


# ------------------------------------------------------------------ Fallback (no SQLite)
func _fallback_write(table: String, row: Dictionary) -> bool:
	var file := FileAccess.open(FALLBACK_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(FALLBACK_PATH) else FileAccess.WRITE)
	if file == null:
		return false
	file.seek_end()
	var entry: Dictionary = row.duplicate()
	entry["table"] = table
	entry["written_at"] = _now()
	file.store_line(JSON.stringify(entry))
	file.close()
	return true


## Stable pseudo-id from the LRN hash so fallback rows still group by student.
func _fallback_register(key: String, grade: String) -> int:
	var fake_id: int = absi(key.hash()) % 1000000 + 1
	_fallback_write("students", {"student_id": fake_id, "lrn": key, "grade_section": grade})
	return fake_id
