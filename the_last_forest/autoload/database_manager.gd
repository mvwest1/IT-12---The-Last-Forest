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
## class list can re-identify students. Keep the salt out of your manuscript and out of GitHub.

const DB_PATH: String = "user://the_last_forest_eval.db"
const FALLBACK_PATH: String = "user://eval_fallback.jsonl"
const EXPORT_DIR: String = "user://exports"
const SCHEMA_VERSION: int = 2

const STORE_IDENTIFIERS_IN_CLEAR: bool = false
## The LRN salt is a secret: it lives in res://local_settings.cfg (git-ignored),
## read through LocalSettings. It must be identical on every lab PC so the same
## LRN maps to the same student_id across machines.

# ------------------------------------------------------------------ DDL
const DDL: Array[String] = [
	"""CREATE TABLE IF NOT EXISTS students (
		student_id    INTEGER PRIMARY KEY AUTOINCREMENT,
		lrn           TEXT UNIQUE NOT NULL,
		name          TEXT,
		grade_section TEXT,
		registered_at TEXT NOT NULL
	);""",
	"""CREATE TABLE IF NOT EXISTS quiz_results (
		quiz_id     INTEGER PRIMARY KEY AUTOINCREMENT,
		attempt_id  TEXT UNIQUE,
		student_id  INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
		stage_index INTEGER NOT NULL CHECK (stage_index BETWEEN 1 AND 4),
		pre_score   INTEGER CHECK (pre_score  IS NULL OR pre_score  >= 0),
		post_score  INTEGER CHECK (post_score IS NULL OR post_score >= 0),
		timestamp   TEXT    NOT NULL
	);""",
	"""CREATE TABLE IF NOT EXISTS session_records (
		session_id      INTEGER PRIMARY KEY AUTOINCREMENT,
		attempt_id      TEXT UNIQUE,
		quiz_id         INTEGER REFERENCES quiz_results(quiz_id) ON DELETE SET NULL,
		student_id      INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
		stage_index     INTEGER NOT NULL CHECK (stage_index BETWEEN 1 AND 4),
		seeds_collected INTEGER NOT NULL DEFAULT 0 CHECK (seeds_collected >= 0),
		trees_matured   INTEGER NOT NULL DEFAULT 0 CHECK (trees_matured >= 0),
		completion_time REAL    NOT NULL CHECK (completion_time >= 0),
		tips_viewed     INTEGER NOT NULL DEFAULT 0 CHECK (tips_viewed >= 0),
		completed_at    TEXT    NOT NULL
	);""",
	"CREATE INDEX IF NOT EXISTS idx_session_student_stage ON session_records(student_id, stage_index);",
	"CREATE INDEX IF NOT EXISTS idx_quiz_student_stage ON quiz_results(student_id, stage_index, timestamp);",
]

const POST_MIGRATION_INDEXES: Array[String] = [
	"CREATE INDEX IF NOT EXISTS idx_session_attempt ON session_records(attempt_id);",
	"CREATE INDEX IF NOT EXISTS idx_session_quiz_id ON session_records(quiz_id);",
	"CREATE INDEX IF NOT EXISTS idx_quiz_attempt ON quiz_results(attempt_id);",
]

## One row per completed stage attempt, paired with its exact quiz_results row
## via explicit attempt_id / quiz_id so repeated attempts on the same stage
## can never be paired with the wrong quiz.
const EXPORT_SQL: String = """
SELECT s.student_id,
       s.grade_section,
       r.session_id,
       r.attempt_id,
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
LEFT JOIN quiz_results q ON (
    (r.quiz_id IS NOT NULL AND q.quiz_id = r.quiz_id)
    OR (r.quiz_id IS NULL AND r.attempt_id IS NOT NULL AND r.attempt_id != '' AND q.attempt_id = r.attempt_id)
)
ORDER BY s.student_id, r.stage_index, r.completed_at, r.session_id;
"""

const EXPORT_COLUMNS: Array[String] = [
	"student_id", "grade_section", "session_id", "attempt_id", "stage_index", "pre_score",
	"post_score", "score_gain", "seeds_collected", "trees_matured",
	"completion_time_sec", "tips_viewed", "completed_at",
]

## Optional injection point for tests (an object with the godot-sqlite API).
var backend_override: Variant = null
## Test hook: when true, save_post_quiz or save_stage_record simulates a failure.
var simulate_post_quiz_failure: bool = false
var simulate_stage_record_failure: bool = false

const MAX_QUIZ_SCORE: int = 10
const MAX_GRADE_LEN: int = 40
const MAX_PIN_ATTEMPTS: int = 5
const PIN_LOCKOUT_MSEC: int = 30000

var last_attempt_id: String = ""
var last_saved_quiz_id: int = -1
var use_stage_cache: bool = true
var query_count: int = 0

var _db: Variant = null
var _ready_ok: bool = false
var _in_transaction: bool = false
var _tx_fallback_buffer: Array[Dictionary] = []
var _highest_stage_cache: Dictionary = {}
var _attempt_seq: int = 0
var _fallback_quiz_seq: int = 1000
var _fallback_session_seq: int = 1000
var _failed_pin_attempts: int = 0
var _pin_locked_until_msec: int = 0
static var _lrn_regex: RegEx = null


func _ready() -> void:
	init_db()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_close()


# ================================================================== Core API
func init_db() -> void:
	init_db_at(DB_PATH)


## Opens (or creates) the database at `path`. Tests use a throwaway file.
func init_db_at(path: String) -> void:
	if _ready_ok:
		return
	_in_transaction = false
	_tx_fallback_buffer.clear()
	_highest_stage_cache.clear()
	_failed_pin_attempts = 0
	_pin_locked_until_msec = 0
	_db = backend_override if backend_override != null else _create_backend()
	if _db == null:
		push_warning("DatabaseManager: godot-sqlite not installed — using JSONL fallback at "
				+ FALLBACK_PATH)
		return
	_db.path = path
	_db.foreign_keys = true
	_db.verbosity_level = 0  # QUIET
	if not _db.open_db():
		push_error("DatabaseManager: could not open %s — %s" % [path, str(_db.error_message)])
		_db = null
		return
	_exec("PRAGMA journal_mode = WAL;")   # safer if the PC is switched off mid-write
	for statement: String in DDL:
		if not _exec(statement):
			push_error("DatabaseManager: DDL failed — " + str(_db.error_message))
			return
	if not _migrate_schema():
		push_error("DatabaseManager: schema migration failed — " + str(_db.error_message))
		return
	for idx_sql: String in POST_MIGRATION_INDEXES:
		if not _exec(idx_sql):
			push_error("DatabaseManager: index DDL failed — " + str(_db.error_message))
			return
	_exec("PRAGMA user_version = %d;" % SCHEMA_VERSION)
	_ready_ok = true


func is_available() -> bool:
	return _ready_ok


## Generates an explicit unique identifier linking one attempt's quiz_results
## row and session_records row so repeated attempts on the same stage never
## cross-pair.
func new_attempt_id(student_id: int = -1, stage_idx: int = 0) -> String:
	_attempt_seq += 1
	var unix_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	var ticks: int = Time.get_ticks_usec()
	var id: String = "att_%d_s%d_%d_%d_%d" % [maxi(student_id, 0), maxi(stage_idx, 0), unix_ms, ticks, _attempt_seq]
	last_attempt_id = id
	return id


# ------------------------------------------------------------------ Transactions
func begin_transaction() -> bool:
	if _in_transaction:
		return true
	if not _ready_ok:
		_in_transaction = true
		_tx_fallback_buffer.clear()
		return true
	if _exec("BEGIN IMMEDIATE TRANSACTION;"):
		_in_transaction = true
		return true
	return false


func commit_transaction() -> bool:
	if not _in_transaction:
		return false
	if not _ready_ok:
		var buffered: Array[Dictionary] = _tx_fallback_buffer.duplicate(true)
		_tx_fallback_buffer.clear()
		_in_transaction = false
		for item: Dictionary in buffered:
			if not _fallback_write_Immediate(str(item.get("table", "")), item.get("row", {})):
				return false
		return true
	var ok: bool = _exec("COMMIT;")
	if ok:
		_in_transaction = false
	else:
		_exec("ROLLBACK;")
		_in_transaction = false
	return ok


func rollback_transaction() -> void:
	if not _in_transaction:
		return
	_highest_stage_cache.clear()
	if not _ready_ok:
		_tx_fallback_buffer.clear()
		_in_transaction = false
		return
	_exec("ROLLBACK;")
	_in_transaction = false


## Returns the student_id (existing one if this LRN is already registered),
## or -1 on failure. LRN must be the 12-digit DepEd Learner Reference Number.
func register_student(lrn: String, name: String, grade_section: String) -> int:
	var clean_lrn: String = lrn.strip_edges()
	if not is_valid_lrn(clean_lrn):
		return -1
	var key: String = _lrn_key(clean_lrn)
	var stored_name: String = _sanitize_text(name) if STORE_IDENTIFIERS_IN_CLEAR else ""
	var grade: String = _sanitize_text(grade_section).left(MAX_GRADE_LEN)
	if grade == "":
		return -1
	if not _ready_ok:
		var fid: int = _fallback_register(key, grade)
		_highest_stage_cache.erase(fid)
		return fid
	_exec_bind(
		"INSERT OR IGNORE INTO students (lrn, name, grade_section, registered_at)"
		+ " VALUES (?, ?, ?, ?);",
		[key, stored_name, grade, _now()])
	# Keep grade/section current if the student was registered before.
	_exec_bind("UPDATE students SET grade_section = ? WHERE lrn = ?;", [grade, key])
	if not _exec_bind("SELECT student_id FROM students WHERE lrn = ?;", [key]):
		return -1
	var rows: Array = _db.query_result
	var sid: int = int(rows[0]["student_id"]) if rows.size() > 0 else -1
	if sid > 0:
		_highest_stage_cache.erase(sid)
	return sid


func save_stage_record(student_id: int, stage_idx: int, seeds: int, trees: int,
		duration: float, tips: int, attempt_id: String = "", quiz_id: int = -1) -> bool:
	if simulate_stage_record_failure or student_id <= 0 or stage_idx < 1 or stage_idx > 4:
		return false
	var resolved_attempt: String = attempt_id.strip_edges()
	if resolved_attempt == "":
		resolved_attempt = last_attempt_id if last_attempt_id != "" else new_attempt_id(student_id, stage_idx)
	var resolved_quiz_id: Variant = quiz_id if quiz_id > 0 else null
	if resolved_quiz_id == null and _ready_ok and resolved_attempt != "":
		if _exec_bind("SELECT quiz_id FROM quiz_results WHERE attempt_id = ? LIMIT 1;", [resolved_attempt]):
			var qrows: Array = _db.query_result
			if qrows.size() > 0:
				resolved_quiz_id = int(qrows[0]["quiz_id"])
	var row: Dictionary = {
		"attempt_id": resolved_attempt,
		"quiz_id": resolved_quiz_id,
		"student_id": student_id,
		"stage_index": stage_idx,
		"seeds_collected": maxi(seeds, 0),
		"trees_matured": maxi(trees, 0),
		"completion_time": maxf(duration, 0.0),
		"tips_viewed": maxi(tips, 0),
		"completed_at": _now(),
	}
	if not _ready_ok:
		_fallback_session_seq += 1
		row["session_id"] = _fallback_session_seq
		var fb_ok: bool = _fallback_write("session_records", row)
		if fb_ok:
			_highest_stage_cache[student_id] = maxi(int(_highest_stage_cache.get(student_id, 0)), stage_idx)
		return fb_ok
	var ok: bool = _exec_bind(
		"INSERT INTO session_records (attempt_id, quiz_id, student_id, stage_index,"
		+ " seeds_collected, trees_matured, completion_time, tips_viewed, completed_at)"
		+ " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
		+ " ON CONFLICT(attempt_id) DO UPDATE SET"
		+ " quiz_id = COALESCE(excluded.quiz_id, session_records.quiz_id),"
		+ " seeds_collected = excluded.seeds_collected,"
		+ " trees_matured = excluded.trees_matured,"
		+ " completion_time = excluded.completion_time,"
		+ " tips_viewed = excluded.tips_viewed,"
		+ " completed_at = excluded.completed_at;",
		[row.attempt_id, row.quiz_id, row.student_id, row.stage_index, row.seeds_collected,
			row.trees_matured, row.completion_time, row.tips_viewed, row.completed_at])
	if ok:
		_highest_stage_cache[student_id] = maxi(int(_highest_stage_cache.get(student_id, 0)), stage_idx)
	return ok


## Pre-test: creates the quiz row for this attempt. Returns quiz_id (or -1).
func save_pre_quiz(student_id: int, stage_idx: int, pre_score: int, attempt_id: String = "") -> int:
	if student_id <= 0 or stage_idx < 1 or stage_idx > 4 or pre_score < 0 or pre_score > MAX_QUIZ_SCORE:
		return -1
	var resolved_attempt: String = attempt_id.strip_edges()
	if resolved_attempt == "":
		resolved_attempt = new_attempt_id(student_id, stage_idx)
	else:
		last_attempt_id = resolved_attempt
	var ts: String = _now()
	if not _ready_ok:
		_fallback_quiz_seq += 1
		var fallback_qid: int = _fallback_quiz_seq
		if not _fallback_write("quiz_results", {
			"quiz_id": fallback_qid,
			"attempt_id": resolved_attempt,
			"student_id": student_id,
			"stage_index": stage_idx,
			"pre_score": pre_score,
			"timestamp": ts,
		}):
			return -1
		last_saved_quiz_id = fallback_qid
		return fallback_qid
	if not _exec_bind(
			"INSERT INTO quiz_results (attempt_id, student_id, stage_index, pre_score, post_score, timestamp)"
			+ " VALUES (?, ?, ?, ?, NULL, ?)"
			+ " ON CONFLICT(attempt_id) DO UPDATE SET pre_score = excluded.pre_score, timestamp = excluded.timestamp;",
			[resolved_attempt, student_id, stage_idx, pre_score, ts]):
		return -1
	var qid: int = int(_db.last_insert_rowid)
	if qid <= 0 and _exec_bind("SELECT quiz_id FROM quiz_results WHERE attempt_id = ? LIMIT 1;", [resolved_attempt]):
		var rows: Array = _db.query_result
		if rows.size() > 0:
			qid = int(rows[0]["quiz_id"])
	last_saved_quiz_id = qid
	return qid


## Post-test: fills post_score on the row created by save_pre_quiz (matched by
## quiz_id or attempt_id). If the pre row is missing, inserts a row linked to
## attempt_id so the attempt's quiz and stage records remain explicitly paired.
func save_post_quiz(quiz_id: int, student_id: int, stage_idx: int, post_score: int,
		attempt_id: String = "", pre_score: Variant = null) -> bool:
	if simulate_post_quiz_failure or student_id <= 0 or stage_idx < 1 or stage_idx > 4 or post_score < 0 or post_score > MAX_QUIZ_SCORE:
		return false
	if pre_score != null and (int(pre_score) < 0 or int(pre_score) > MAX_QUIZ_SCORE):
		return false
	var resolved_attempt: String = attempt_id.strip_edges()
	if resolved_attempt == "":
		resolved_attempt = last_attempt_id if last_attempt_id != "" else new_attempt_id(student_id, stage_idx)
	var clean_pre: Variant = int(pre_score) if (pre_score != null and int(pre_score) >= 0) else null
	if not _ready_ok:
		var fallback_qid: int = quiz_id
		if fallback_qid <= 0:
			_fallback_quiz_seq += 1
			fallback_qid = _fallback_quiz_seq
		var payload: Dictionary = {
			"quiz_id": fallback_qid,
			"attempt_id": resolved_attempt,
			"student_id": student_id,
			"stage_index": stage_idx,
			"post_score": post_score,
			"timestamp": _now(),
		}
		if clean_pre != null:
			payload["pre_score"] = clean_pre
		var ok_fb: bool = _fallback_write("quiz_results", payload)
		if ok_fb:
			last_saved_quiz_id = fallback_qid
		return ok_fb
	if quiz_id > 0:
		if not _exec_bind(
				"UPDATE quiz_results SET post_score = ?,"
				+ " attempt_id = COALESCE(NULLIF(attempt_id, ''), ?),"
				+ " pre_score = COALESCE(pre_score, ?)"
				+ " WHERE quiz_id = ? AND student_id = ? AND stage_index = ?;",
				[post_score, resolved_attempt, clean_pre, quiz_id, student_id, stage_idx]):
			return false
		if _changes() > 0:
			last_saved_quiz_id = quiz_id
			return true
		return false
	if resolved_attempt != "":
		if _exec_bind("SELECT quiz_id FROM quiz_results WHERE attempt_id = ? AND student_id = ? AND stage_index = ? LIMIT 1;",
				[resolved_attempt, student_id, stage_idx]):
			var existing: Array = _db.query_result
			if existing.size() > 0:
				var found_qid: int = int(existing[0]["quiz_id"])
				if not _exec_bind(
						"UPDATE quiz_results SET post_score = ?, pre_score = COALESCE(pre_score, ?) WHERE quiz_id = ?;",
						[post_score, clean_pre, found_qid]):
					return false
				if _changes() > 0:
					last_saved_quiz_id = found_qid
					return true
				return false
	if not _exec_bind(
			"INSERT INTO quiz_results (attempt_id, student_id, stage_index, pre_score, post_score, timestamp)"
			+ " VALUES (?, ?, ?, ?, ?, ?);",
			[resolved_attempt, student_id, stage_idx, clean_pre, post_score, _now()]):
		return false
	last_saved_quiz_id = int(_db.last_insert_rowid)
	return last_saved_quiz_id > 0


## Saves both the post-quiz update and the stage completion record inside a
## single database transaction. Confirms both succeed and rolls back if either
## fails so partial attempt records are never persisted.
func save_stage_completion(student_id: int, stage_idx: int, quiz_id: int, post_score: int,
		seeds: int, trees: int, duration: float, tips: int,
		attempt_id: String = "", pre_score: Variant = null) -> bool:
	if student_id <= 0 or stage_idx < 1 or stage_idx > 4 or post_score < 0:
		return false
	var resolved_attempt: String = attempt_id.strip_edges()
	if resolved_attempt == "":
		resolved_attempt = last_attempt_id if last_attempt_id != "" else new_attempt_id(student_id, stage_idx)
	if not begin_transaction():
		return false
	var quiz_ok: bool = save_post_quiz(quiz_id, student_id, stage_idx, post_score, resolved_attempt, pre_score)
	var linked_quiz_id: int = quiz_id if quiz_id > 0 else last_saved_quiz_id
	var stage_ok: bool = quiz_ok and save_stage_record(
			student_id, stage_idx, seeds, trees, duration, tips, resolved_attempt, linked_quiz_id)
	if quiz_ok and stage_ok and commit_transaction():
		return true
	rollback_transaction()
	return false


## Highest stage index this student has cleared (0 = none). Drives unlocks.
## Uses an in-memory per-student cache invalidated on writes/rollbacks so
## Stage Select does not issue redundant SQLite queries for each stage card.
func get_highest_completed_stage(student_id: int) -> int:
	if student_id < 0:
		return 0
	if use_stage_cache and _highest_stage_cache.has(student_id):
		return int(_highest_stage_cache[student_id])
	if not _ready_ok:
		var fb_best: int = _fallback_highest_completed_stage(student_id)
		if use_stage_cache:
			_highest_stage_cache[student_id] = fb_best
		return fb_best
	if not _exec_bind("SELECT COALESCE(MAX(stage_index), 0) AS best FROM session_records WHERE student_id = ?;", [student_id]):
		return 0
	var rows: Array = _db.query_result
	var best: int = int(rows[0]["best"]) if rows.size() > 0 else 0
	if use_stage_cache:
		_highest_stage_cache[student_id] = best
	return best


## RETRIEVE: this student's saved stage attempts, newest first, for the
## in-game "My Records" panel. Each row: session_id, attempt_id, quiz_id,
## stage_index, pre_score, post_score, trees_matured, seeds_collected,
## completion_time, completed_at.
## Paired by explicit quiz_id / attempt_id (never by timestamp guessing).
const RECORDS_SQL: String = """
SELECT r.session_id,
       r.attempt_id,
       r.quiz_id,
       r.stage_index,
       q.pre_score,
       q.post_score,
       r.trees_matured,
       r.seeds_collected,
       r.completion_time,
       r.completed_at
FROM session_records r
LEFT JOIN quiz_results q ON (
    (r.quiz_id IS NOT NULL AND q.quiz_id = r.quiz_id)
    OR (r.quiz_id IS NULL AND r.attempt_id IS NOT NULL AND r.attempt_id != '' AND q.attempt_id = r.attempt_id)
)
WHERE r.student_id = ?
ORDER BY r.completed_at DESC, r.session_id DESC
LIMIT ?;
"""


func get_student_records(student_id: int, limit: int = 8) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if student_id < 0 or limit <= 0:
		return out
	var safe_limit: int = clampi(limit, 1, 50)
	if not _ready_ok:
		return _fallback_student_records(student_id, safe_limit)
	if not _exec_bind(RECORDS_SQL, [student_id, safe_limit]):
		return out
	for row: Dictionary in _db.query_result:
		out.append(row)
	return out


## Same rows from the backup journal when SQLite is unavailable, paired by
## explicit attempt_id / quiz_id.
func _fallback_student_records(student_id: int, limit: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var quizzes: Array[Dictionary] = []
	if not FileAccess.file_exists(FALLBACK_PATH):
		return records
	var file := FileAccess.open(FALLBACK_PATH, FileAccess.READ)
	if file == null:
		return records
	while not file.eof_reached():
		var parsed: Variant = JSON.parse_string(file.get_line())
		if not (parsed is Dictionary) or int((parsed as Dictionary).get("student_id", -1)) != student_id:
			continue
		var entry: Dictionary = parsed
		match str(entry.get("table", "")):
			"session_records": records.append(entry)
			"quiz_results": quizzes.append(entry)
	file.close()
	for rec: Dictionary in records:
		var matched: Dictionary = _match_fallback_quiz(rec, quizzes)
		if matched.has("pre_score"):
			rec["pre_score"] = matched["pre_score"]
		if matched.has("post_score"):
			rec["post_score"] = matched["post_score"]
	records.reverse()
	return records.slice(0, limit)


# ------------------------------------------------------------------ Teacher Authorization & Export
func is_pin_locked_out() -> bool:
	return Time.get_ticks_msec() < _pin_locked_until_msec


func reset_pin_lockout() -> void:
	_failed_pin_attempts = 0
	_pin_locked_until_msec = 0


## Verifies the teacher PIN at the service layer with brute-force lockout
## after MAX_PIN_ATTEMPTS consecutive failures (OWASP A01:2025 & A07:2025).
func verify_teacher_pin(pin: String) -> bool:
	if is_pin_locked_out():
		return false
	var expected: String = LocalSettings.value("teacher_pin").strip_edges()
	var candidate: String = pin.strip_edges()
	if expected != "" and candidate == expected:
		_failed_pin_attempts = 0
		_pin_locked_until_msec = 0
		return true
	_failed_pin_attempts += 1
	if _failed_pin_attempts >= MAX_PIN_ATTEMPTS:
		_pin_locked_until_msec = Time.get_ticks_msec() + PIN_LOCKOUT_MSEC
	return false


## Authorized export entry point for the Teacher Panel: enforces teacher PIN
## verification at the DatabaseManager boundary before exporting class records.
func export_eval_csv_for_teacher(pin: String) -> String:
	if not verify_teacher_pin(pin):
		return ""
	return export_eval_csv()


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
		var paired_quiz: Dictionary = _match_fallback_quiz(record, quizzes)
		var student: Dictionary = students.get(int(record.get("student_id", -1)), {})
		var row: Dictionary = {
			"student_id": record.get("student_id"),
			"grade_section": record.get("grade_section", student.get("grade_section", "")),
			"session_id": record.get("session_id", ""),
			"attempt_id": record.get("attempt_id", ""),
			"stage_index": record.get("stage_index", ""),
			"pre_score": paired_quiz.get("pre_score"),
			"post_score": paired_quiz.get("post_score"),
			"score_gain": int(paired_quiz.get("post_score", 0)) - int(paired_quiz.get("pre_score", 0)) if paired_quiz.has("post_score") and paired_quiz.has("pre_score") else null,
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


func _match_fallback_quiz(record: Dictionary, quizzes: Array[Dictionary]) -> Dictionary:
	var rec_attempt: String = str(record.get("attempt_id", "")).strip_edges()
	var rec_qid: int = int(record.get("quiz_id", -1)) if record.get("quiz_id") != null else -1
	var merged: Dictionary = {}
	for quiz: Dictionary in quizzes:
		var q_attempt: String = str(quiz.get("attempt_id", "")).strip_edges()
		var q_id: int = int(quiz.get("quiz_id", -1)) if quiz.get("quiz_id") != null else -1
		var matches: bool = false
		if rec_attempt != "" and q_attempt == rec_attempt:
			matches = true
		elif rec_attempt == "" and rec_qid > 0 and q_id == rec_qid:
			matches = true
		if matches:
			if quiz.has("pre_score") and quiz.get("pre_score") != null:
				merged["pre_score"] = quiz["pre_score"]
			if quiz.has("post_score") and quiz.get("post_score") != null:
				merged["post_score"] = quiz["post_score"]
	return merged


# ================================================================== Helpers
static func is_valid_lrn(lrn: String) -> bool:
	if _lrn_regex == null:
		_lrn_regex = RegEx.create_from_string("^\\d{12}$")
	return _lrn_regex.search(lrn) != null


static func _sanitize_text(raw: String) -> String:
	return raw.replace("\r", " ").replace("\n", " ").replace("\t", " ").strip_edges()


func _lrn_key(lrn: String) -> String:
	if STORE_IDENTIFIERS_IN_CLEAR:
		return lrn
	return "h:" + (LocalSettings.value("lrn_salt") + lrn).sha256_text()


func _now() -> String:
	return Time.get_datetime_string_from_system(false, true)  # "YYYY-MM-DD HH:MM:SS" local


func _create_backend() -> Variant:
	if ClassDB.class_exists(&"SQLite"):
		return ClassDB.instantiate(&"SQLite")
	return null


func _migrate_schema() -> bool:
	if not _has_column("quiz_results", "attempt_id"):
		if not _exec("ALTER TABLE quiz_results ADD COLUMN attempt_id TEXT;"):
			return false
	if not _has_column("session_records", "attempt_id"):
		if not _exec("ALTER TABLE session_records ADD COLUMN attempt_id TEXT;"):
			return false
	if not _has_column("session_records", "quiz_id"):
		if not _exec("ALTER TABLE session_records ADD COLUMN quiz_id INTEGER REFERENCES quiz_results(quiz_id) ON DELETE SET NULL;"):
			return false
	return true


func _has_column(table: String, column: String) -> bool:
	if not _exec("PRAGMA table_info(%s);" % table):
		return false
	for info: Dictionary in _db.query_result:
		if str(info.get("name", "")) == column:
			return true
	return false


func _changes() -> int:
	if not _exec("SELECT changes() AS n;"):
		return 0
	var rows: Array = _db.query_result
	return int(rows[0]["n"]) if rows.size() > 0 else 0


func _exec(sql: String) -> bool:
	if _db == null:
		return false
	query_count += 1
	var ok: bool = _db.query(sql)
	if not ok:
		push_error("SQL failed: %s\n%s" % [str(_db.error_message), sql])
	return ok


func _exec_bind(sql: String, bindings: Array) -> bool:
	if _db == null:
		return false
	query_count += 1
	var ok: bool = _db.query_with_bindings(sql, bindings)
	if not ok:
		push_error("SQL failed: %s\n%s" % [str(_db.error_message), sql])
	return ok


func _close() -> void:
	if _in_transaction:
		rollback_transaction()
	if _db != null and _ready_ok:
		_db.close_db()
	_highest_stage_cache.clear()
	_ready_ok = false


static func _csv_cell(value: Variant) -> String:
	if value == null:
		return ""
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 1e15:
		value = int(value)  # SQLite INTEGER columns may arrive as float
	var text: String = str(value)
	# Prevent CSV spreadsheet formula injection on non-numeric text strings.
	if not (value is int or value is float) and text.length() > 0:
		var first_char: String = text.left(1)
		if first_char in ["=", "+", "-", "@"] and not text.is_valid_float():
			text = "'" + text
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
	if _in_transaction:
		_tx_fallback_buffer.append({"table": table, "row": row.duplicate(true)})
		return true
	return _fallback_write_Immediate(table, row)


func _fallback_write_Immediate(table: String, row: Dictionary) -> bool:
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
