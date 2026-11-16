class_name LocalSettings
extends RefCounted
## Secrets that must NOT be uploaded to GitHub (activity security rule).
##
##   res://local_settings.cfg         <- the REAL values, git-ignored (.gitignore)
##   res://local_settings.sample.cfg  <- committed example with dummy values
##
## Setup on a new PC / fresh clone: copy local_settings.sample.cfg to
## local_settings.cfg and put in your own teacher PIN and a long random salt.
## Use the SAME salt on every lab PC, and never change it after the pilot
## starts (the salt turns each LRN into the same student code every time).

const LOCAL_PATH: String = "res://local_settings.cfg"
const USER_LOCAL_PATH: String = "user://local_settings.cfg"
const SAMPLE_PATH: String = "res://local_settings.sample.cfg"
const SECTION: String = "secrets"

static var _cfg: ConfigFile = null
static var _from_sample: bool = false


static func value(key: String, fallback: String = "") -> String:
	_load()
	return str(_cfg.get_value(SECTION, key, fallback))


## True when the real file is missing and the public sample values are used.
static func using_sample() -> bool:
	_load()
	return _from_sample


static func reload() -> void:
	_cfg = null
	_from_sample = false
	_load()


static func _load() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	var exe_dir_cfg: String = OS.get_executable_path().get_base_dir().path_join("local_settings.cfg")
	for candidate: String in [LOCAL_PATH, USER_LOCAL_PATH, exe_dir_cfg]:
		if candidate != "" and FileAccess.file_exists(candidate) and _cfg.load(candidate) == OK:
			_from_sample = false
			return
	_from_sample = true
	if _cfg.load(SAMPLE_PATH) != OK:
		push_error("LocalSettings: neither %s nor %s found" % [LOCAL_PATH, SAMPLE_PATH])
	else:
		push_warning("LocalSettings: using SAMPLE values from %s. Create %s before the pilot." % [SAMPLE_PATH, LOCAL_PATH])
