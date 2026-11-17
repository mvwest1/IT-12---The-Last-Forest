class_name LocalSettings
extends RefCounted
## Device secrets: the teacher PIN and the LRN salt. They must NEVER be
## uploaded to GitHub or baked into the APK/EXE.
##
## Where they are read from (first file found wins):
##   1. res://local_settings.cfg      developer copy, git-ignored
##   2. user://local_settings.cfg     created by the game on first launch
##   3. <folder of the .exe>/local_settings.cfg   shared file for lab PCs
##
## If none exists (fresh Android install, new PC) the game creates
## user://local_settings.cfg with a NEW random salt and NO PIN, and the
## Teacher button asks the teacher to create a PIN first. A PIN created in
## the game is stored only as a salted SHA-256 hash (teacher_pin_hash).
## The committed local_settings.sample.cfg is documentation only.
##
## Lab PCs that must share student codes: copy the SAME local_settings.cfg
## next to TheLastForest.exe on every PC (same salt = same student code).

const LOCAL_PATH: String = "res://local_settings.cfg"
const USER_LOCAL_PATH: String = "user://local_settings.cfg"
const SAMPLE_PATH: String = "res://local_settings.sample.cfg"
const SECTION: String = "secrets"
const MIN_PIN_LEN: int = 4
const MAX_PIN_LEN: int = 8

static var _cfg: ConfigFile = null
static var _from_sample: bool = false
static var _path: String = ""


static func value(key: String, fallback: String = "") -> String:
	_load()
	return str(_cfg.get_value(SECTION, key, fallback))


## Kept for older tests/tools: true only if the public sample had to be used.
static func using_sample() -> bool:
	_load()
	return _from_sample


static func source_path() -> String:
	_load()
	return _path


## In-memory settings (tests use this; nothing is written to disk).
static func config() -> ConfigFile:
	_load()
	return _cfg


static func reload() -> void:
	_cfg = null
	_from_sample = false
	_path = ""
	_load()


## True when no teacher PIN exists yet (first launch on a new device).
static func needs_pin_setup() -> bool:
	return value("teacher_pin").strip_edges() == "" and value("teacher_pin_hash").strip_edges() == ""


static func is_valid_new_pin(pin: String) -> bool:
	if pin.length() < MIN_PIN_LEN or pin.length() > MAX_PIN_LEN:
		return false
	for c: String in pin:
		if c < "0" or c > "9":
			return false
	return true


## Compares against the stored PIN (plain text in a hand-made file, or the
## hash written by the game) without stopping at the first wrong character.
static func check_pin(candidate: String) -> bool:
	var pin: String = candidate.strip_edges()
	if pin == "":
		return false
	var stored_hash: String = value("teacher_pin_hash").strip_edges()
	var expected: String
	var given: String
	if stored_hash != "":
		expected = stored_hash
		given = _pin_hash(pin)
	else:
		expected = value("teacher_pin").strip_edges()
		given = pin
		if expected == "":
			return false
	var diff: int = expected.length() ^ given.length()
	for i: int in mini(expected.length(), given.length()):
		diff |= expected.unicode_at(i) ^ given.unicode_at(i)
	return diff == 0


## Sets (or changes) the teacher PIN. Stored only as a hash. Returns false
## if the PIN is not 4-8 digits or the settings file cannot be written.
static func set_teacher_pin(pin: String) -> bool:
	_load()
	if not is_valid_new_pin(pin):
		return false
	_cfg.set_value(SECTION, "teacher_pin_hash", _pin_hash(pin))
	if _cfg.has_section_key(SECTION, "teacher_pin"):
		_cfg.erase_section_key(SECTION, "teacher_pin")
	var target: String = _path
	if target == "" or target == SAMPLE_PATH or (target.begins_with("res://") and not OS.has_feature("editor")):
		target = USER_LOCAL_PATH
	if _cfg.save(target) != OK:
		return false
	_path = target
	_from_sample = false
	return true


static func _pin_hash(pin: String) -> String:
	return ("pin:" + value("lrn_salt") + ":" + pin).sha256_text()


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	var exe_dir_cfg: String = OS.get_executable_path().get_base_dir().path_join("local_settings.cfg")
	for candidate: String in [LOCAL_PATH, USER_LOCAL_PATH, exe_dir_cfg]:
		if candidate != "" and FileAccess.file_exists(candidate) and _cfg.load(candidate) == OK:
			_from_sample = false
			_path = candidate
			# A hand-made file without a salt would hash LRNs unsalted: add one.
			if str(_cfg.get_value(SECTION, "lrn_salt", "")).strip_edges() == "":
				_cfg.set_value(SECTION, "lrn_salt", Crypto.new().generate_random_bytes(32).hex_encode())
				_cfg.save(candidate if not candidate.begins_with("res://") else USER_LOCAL_PATH)
			return
	# First launch on this device: create private settings with a fresh salt.
	_cfg = ConfigFile.new()
	var crypto := Crypto.new()
	_cfg.set_value(SECTION, "lrn_salt", crypto.generate_random_bytes(32).hex_encode())
	if _cfg.save(USER_LOCAL_PATH) == OK:
		_path = USER_LOCAL_PATH
		_from_sample = false
		return
	# Storage not writable (should never happen): fall back to the public sample.
	_from_sample = true
	_path = SAMPLE_PATH
	if _cfg.load(SAMPLE_PATH) != OK:
		push_error("LocalSettings: could not create %s or read %s" % [USER_LOCAL_PATH, SAMPLE_PATH])
