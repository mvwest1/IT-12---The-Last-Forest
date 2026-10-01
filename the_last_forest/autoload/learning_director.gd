extends Node
## LearningDirector (Autoload #3) — decides WHEN a climate fact is shown.
##
## Anti-frustration rules for primary-school players:
##   * Each fact is shown once (unless forced, e.g. the stage-end card).
##   * Never during a jump or while holding the interact key.
##   * NORMAL facts respect a cooldown so cards don't stack up.
##   * HIGH facts (stage intro, milestones) skip the cooldown.
##   * If a "good moment" never arrives, show anyway after MAX_WAIT_MSEC
##     (the game is paused while the card is open, so it is always safe).

enum Priority { LOW = 0, NORMAL = 1, HIGH = 2 }

const FACT_DIR: String = "res://the_last_forest/data/facts/"
const COOLDOWN_MSEC: int = 35000
const MAX_WAIT_MSEC: int = 6000
const PAUSE_OWNER: StringName = &"fact_card"

var _facts: Dictionary = {}          # StringName -> ClimateFact
var _queue: Array[Dictionary] = []   # {"id": StringName, "priority": int}
var _popup: FactCardPopup = null
var _quiz_popup: QuizModal = null
var _quiz_running: bool = false
var _showing: StringName = &""
var _opened_msec: int = 0
var _last_closed_msec: int = -COOLDOWN_MSEC
var _waiting_since: int = -1


func _ready() -> void:
	_load_facts()


func _load_facts() -> void:
	var dir := DirAccess.open(FACT_DIR)
	if dir == null:
		push_warning("LearningDirector: fact folder not found: " + FACT_DIR)
		return
	for file_name: String in dir.get_files():
		# Exported builds list "x.tres.remap" instead of "x.tres".
		var clean: String = file_name.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var fact := load(FACT_DIR + clean) as ClimateFact
		if fact != null and fact.id != &"":
			_facts[fact.id] = fact


# ------------------------------------------------------------------ Public API
func register_popup(popup: FactCardPopup) -> void:
	_popup = popup
	if not popup.closed.is_connected(_on_popup_closed):
		popup.closed.connect(_on_popup_closed)


func register_quiz_popup(popup: QuizModal) -> void:
	_quiz_popup = popup


## Runs a pre- or post-test. Pauses gameplay, returns the number of correct
## answers, or -1 if no QuizModal is in the scene / the set is empty.
func run_quiz(quiz: QuizSet, phase: StringName) -> int:
	if quiz == null or quiz.questions.is_empty():
		return -1
	if _quiz_popup == null or not is_instance_valid(_quiz_popup):
		push_warning("LearningDirector: no QuizModal registered; skipping quiz.")
		return -1
	_quiz_running = true
	GameState.request_pause(&"quiz")
	EventBus.quiz_started.emit(quiz.stage_index, phase)
	_quiz_popup.present(quiz, phase)
	var score: int = await _quiz_popup.finished
	GameState.release_pause(&"quiz")
	_quiz_running = false
	EventBus.quiz_finished.emit(quiz.stage_index, phase, score, quiz.questions.size())
	return score


func get_fact(fact_id: StringName) -> ClimateFact:
	return _facts.get(fact_id) as ClimateFact


## For a "Leaf Journal" screen in the pause menu.
func get_unlocked_facts() -> Array[ClimateFact]:
	var result: Array[ClimateFact] = []
	for fact_id: StringName in GameState.unlocked_facts:
		if _facts.has(fact_id):
			result.append(_facts[fact_id])
	return result


## Returns true if a pausing CARD will open (so callers may `await
## EventBus.fact_card_closed`). TIPs and already-seen facts return false.
func request_fact(fact_id: StringName, priority: int = Priority.NORMAL, force: bool = false) -> bool:
	if not _facts.has(fact_id):
		push_warning("LearningDirector: unknown fact id " + String(fact_id))
		return false
	if not force and fact_id in GameState.unlocked_facts:
		return false
	if _showing == fact_id:
		return true
	for entry: Dictionary in _queue:
		if entry["id"] == fact_id:
			return true
	var fact: ClimateFact = _facts[fact_id]
	if fact.delivery == ClimateFact.Delivery.TIP:
		GameState.unlock_fact(fact_id)
		EventBus.tip_requested.emit(fact.body_key)
		return false
	_queue.append({"id": fact_id, "priority": priority})
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] > b["priority"])
	return true


func is_showing() -> bool:
	return _showing != &""


## True when no card is open or waiting.
func is_idle() -> bool:
	return _showing == &"" and _queue.is_empty()


## Called on scene changes so a card queued in one stage never pops up in another.
func clear_queue() -> void:
	_queue.clear()
	_waiting_since = -1
	# A card that was open when the scene changed can never be closed by its
	# (now freed) popup: forget it so the next stage starts clean.
	if _showing != &"":
		_showing = &""
		GameState.release_pause(PAUSE_OWNER)


# ------------------------------------------------------------------ Scheduling
func _process(_delta: float) -> void:
	if _showing != &"" or _queue.is_empty() or _quiz_running:
		return
	if _popup == null or not is_instance_valid(_popup):
		return
	var entry: Dictionary = _queue[0]
	if not _is_good_moment(entry["priority"]):
		return
	_queue.pop_front()
	_open(entry["id"])


func _is_good_moment(priority: int) -> bool:
	# Never stack on top of a tutorial hint card.
	if GameState.is_paused_by(&"climate_tip"):
		return false
	var now: int = Time.get_ticks_msec()
	if priority < Priority.HIGH and now - _last_closed_msec < COOLDOWN_MSEC:
		return false
	if _waiting_since < 0:
		_waiting_since = now
	if now - _waiting_since > MAX_WAIT_MSEC:
		return true
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if player != null and not player.is_on_floor():
		return false
	var interactor := get_tree().get_first_node_in_group(&"player_interactor")
	if interactor != null and interactor.call(&"is_busy"):
		return false
	return true


func _open(fact_id: StringName) -> void:
	_waiting_since = -1
	_showing = fact_id
	_opened_msec = Time.get_ticks_msec()
	GameState.request_pause(PAUSE_OWNER)
	GameState.unlock_fact(fact_id)
	_popup.present(_facts[fact_id])
	EventBus.fact_card_opened.emit(fact_id)


func _on_popup_closed() -> void:
	var fact_id: StringName = _showing
	var seconds: float = (Time.get_ticks_msec() - _opened_msec) / 1000.0
	_showing = &""
	_last_closed_msec = Time.get_ticks_msec()
	GameState.release_pause(PAUSE_OWNER)
	EventBus.fact_card_closed.emit(fact_id, seconds)
