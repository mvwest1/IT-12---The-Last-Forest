extends Node
## Settings (Autoload) — player preferences saved in user://settings.cfg
## (NOT the database: these are per-device, not research data).
##   language       "en" / "fil"
##   music_volume   0..1      sfx_volume 0..1
##   story_seen     the intro story was shown once on this device
##   tap_to_plant   accessibility: tap Plant once instead of holding it

const PATH: String = "user://settings.cfg"
const SECTION: String = "prefs"

var language: String = "en"
var music_volume: float = 0.8
var sfx_volume: float = 0.9
var story_seen: bool = false
var tap_to_plant: bool = false


## Phones/tablets have no "E" key: prompts name the on-screen sprout button.
const TOUCH_WORDING: Dictionary = {
	"en": {
		"PROMPT_HOLD_TO_PLANT": "Hold the sprout button to plant",
		"PROMPT_HOLD_E": "Hold the sprout button to plant",
		"PROMPT_GUARD": "Hold the sprout button to add a tree guard",
		"PROMPT_DIVERTER": "Hold the sprout button to turn the water",
		"PROMPT_REVIVE": "Hold the sprout button to help the tree",
		"PROMPT_WATER": "Hold the sprout button to water",
		"TIP_GUARD_PICKED": "You got a tree guard! Hold the sprout button next to a young tree.",
		"HUD_TAP_MODE": "Tap the sprout button instead of holding",
		"SIGN_PRESS_E": "Tap the sprout",
		"SIGN_1_BODY": "Use the arrow buttons to walk. Press the up arrow to jump. Pick up the seeds!",
		"SIGN_2_BODY": "Stand on the burnt soil. Hold the sprout button until the bar is full to plant a seed.",
	},
	"fil": {
		"PROMPT_HOLD_TO_PLANT": "Diinan ang buton na may punla para magtanim",
		"PROMPT_HOLD_E": "Diinan ang buton na may punla para magtanim",
		"PROMPT_GUARD": "Diinan ang buton na may punla para lagyan ng bakod",
		"PROMPT_DIVERTER": "Diinan ang buton na may punla para ibaling ang tubig",
		"PROMPT_REVIVE": "Diinan ang buton na may punla para tulungan ang puno",
		"PROMPT_WATER": "Diinan ang buton na may punla para diligan",
		"TIP_GUARD_PICKED": "May bakod ka na! Diinan ang buton na may punla sa tabi ng batang puno.",
		"HUD_TAP_MODE": "I-tap ang buton na may punla sa halip na diinan",
		"SIGN_PRESS_E": "I-tap ang punla",
		"SIGN_1_BODY": "Gamitin ang mga arrow na buton para lumakad. Pindutin ang pataas na arrow para tumalon. Pulutin ang mga binhi!",
		"SIGN_2_BODY": "Tumayo sa sunog na lupa. Diinan ang buton na may punla hanggang mapuno ang bar para magtanim.",
	},
}


func _ready() -> void:
	load_settings()
	if DisplayServer.is_touchscreen_available() and not OS.has_feature("editor"):
		use_touch_wording()
	apply()


## Puts touch-screen wording IN FRONT of the normal translations (the
## TranslationServer uses the first translation that has the key).
func use_touch_wording() -> void:
	for locale: String in TOUCH_WORDING:
		var originals: Array[Translation] = []
		for path: String in UiKit.TRANSLATION_FILES.get(locale, []):
			var t := load(path) as Translation
			if t != null:
				originals.append(t)
				TranslationServer.remove_translation(t)
		var touch := Translation.new()
		touch.locale = locale
		var msgs: Dictionary = TOUCH_WORDING[locale]
		for key: String in msgs:
			touch.add_message(StringName(key), msgs[key])
		TranslationServer.add_translation(touch)
		for t: Translation in originals:
			TranslationServer.add_translation(t)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		# First launch: follow the device language if it is Filipino/Tagalog.
		var os_lang: String = OS.get_locale_language()
		language = "fil" if os_lang in ["fil", "tl"] else "en"
		return
	language = str(cfg.get_value(SECTION, "language", language))
	if language not in ["en", "fil"]:
		language = "en"
	music_volume = clampf(float(cfg.get_value(SECTION, "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(SECTION, "sfx_volume", sfx_volume)), 0.0, 1.0)
	story_seen = bool(cfg.get_value(SECTION, "story_seen", false))
	tap_to_plant = bool(cfg.get_value(SECTION, "tap_to_plant", false))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "language", language)
	cfg.set_value(SECTION, "music_volume", music_volume)
	cfg.set_value(SECTION, "sfx_volume", sfx_volume)
	cfg.set_value(SECTION, "story_seen", story_seen)
	cfg.set_value(SECTION, "tap_to_plant", tap_to_plant)
	cfg.save(PATH)


func apply() -> void:
	TranslationServer.set_locale(language)
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


func set_language(code: String) -> void:
	language = code if code in ["en", "fil"] else "en"
	TranslationServer.set_locale(language)
	save()


## Volume setters apply at once; the file is written by save() when the
## slider is released (not 20 times per second while dragging).
func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_set_bus("Music", music_volume)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_set_bus("SFX", sfx_volume)


func mark_story_seen() -> void:
	if not story_seen:
		story_seen = true
		save()


func _set_bus(bus_name: String, v: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))
