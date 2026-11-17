extends CanvasLayer
## On-screen controls for phones/tablets (TouchScreenButtons are only drawn
## on touch screens). The viewport is 800x480 with stretch "keep_height",
## so a wide phone shows a WIDER view: buttons are re-anchored to the real
## visible corners every time the window size changes, never hard-coded.
##
##   [Left][Right] ............................ [Plant][Jump]
##                                       (top-right) [Pause]

const BUTTON_PX: float = 128.0
const MARGIN: float = 14.0
const GAP: float = 10.0

@onready var _left: TouchScreenButton = $Left
@onready var _right: TouchScreenButton = $Right
@onready var _jump: TouchScreenButton = $Jump
@onready var _interact: TouchScreenButton = $Interact
@onready var _pause: TouchScreenButton = get_node_or_null(^"Pause")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must notice the pause to hide
	get_viewport().size_changed.connect(_layout)
	_layout()


## Hide the thumb buttons whenever the game is paused (quiz, fact card,
## pause menu) so they never cover the buttons a child must tap.
func _process(_delta: float) -> void:
	var show: bool = not get_tree().paused
	if visible != show:
		visible = show


func _layout() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	# ~20 % of the screen height per button, clamped so they stay thumb-sized.
	var s: float = clampf(size.y * 0.2 / BUTTON_PX, 0.55, 1.0)
	var b: float = BUTTON_PX * s
	var y: float = size.y - b - MARGIN
	for btn: TouchScreenButton in [_left, _right, _jump, _interact]:
		btn.scale = Vector2(s, s)
	_left.position = Vector2(MARGIN, y)
	_right.position = Vector2(MARGIN + b + GAP, y)
	_jump.position = Vector2(size.x - b - MARGIN, y)
	_interact.position = Vector2(size.x - 2.0 * b - MARGIN - GAP, y)
	if _pause != null:
		var ps: float = s * 0.55
		_pause.scale = Vector2(ps, ps)
		_pause.position = Vector2(size.x - BUTTON_PX * ps - MARGIN, 62.0)
