class_name BGAnimator
extends TextureRect
## scripts/UI/bg_animator.gd
## Drives the jeepney background: a day idle loop, a night idle loop, and a
## one-shot transition that plays between them. Sliced at runtime from
## res://Assets/jeepney_bg_sheet.png (6 columns x 3 rows, 213x120 per frame):
##   Row 0 -> Day idle loop (loops forever while state == DAY)
##   Row 1 -> Day -> Night transition (plays once, then falls into NIGHT)
##   Row 2 -> Night idle loop (loops forever while state == NIGHT)
##
## Usage: GameManager.register_background(this_node), then call
## set_night(true/false) whenever a stage starts. Calling set_night(true)
## while already in NIGHT/TRANSITIONING is a no-op (won't restart the
## transition mid-stage); same for set_night(false) while already in DAY.

const SHEET_PATH := "res://Assets/jeepney_bg_sheet.png"
const FRAME_WIDTH := 213
const FRAME_HEIGHT := 120
const COLUMNS := 6

const ROW_DAY := 0
const ROW_TRANSITION := 1
const ROW_NIGHT := 2

@export var frames_per_second: float = 6.0

enum State { DAY, TRANSITIONING, NIGHT }

var _state: State = State.DAY
var _frame_index: int = 0
var _time_accum: float = 0.0

var _day_frames: Array[Texture2D] = []
var _transition_frames: Array[Texture2D] = []
var _night_frames: Array[Texture2D] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var sheet: Texture2D = load(SHEET_PATH)
	if sheet == null:
		push_warning("BGAnimator: could not load %s" % SHEET_PATH)
		return

	_day_frames = _slice_row(sheet, ROW_DAY)
	_transition_frames = _slice_row(sheet, ROW_TRANSITION)
	_night_frames = _slice_row(sheet, ROW_NIGHT)

	_state = State.DAY
	_frame_index = 0
	if not _day_frames.is_empty():
		texture = _day_frames[0]

func _process(delta: float) -> void:
	if frames_per_second <= 0.0:
		return
	_time_accum += delta
	var frame_duration := 1.0 / frames_per_second
	if _time_accum < frame_duration:
		return
	_time_accum -= frame_duration
	_advance_frame()

func _advance_frame() -> void:
	match _state:
		State.DAY:
			if _day_frames.is_empty():
				return
			_frame_index = (_frame_index + 1) % _day_frames.size()
			texture = _day_frames[_frame_index]
		State.NIGHT:
			if _night_frames.is_empty():
				return
			_frame_index = (_frame_index + 1) % _night_frames.size()
			texture = _night_frames[_frame_index]
		State.TRANSITIONING:
			_frame_index += 1
			if _frame_index >= _transition_frames.size():
				# Transition finished -- settle into the night loop.
				_state = State.NIGHT
				_frame_index = 0
				if not _night_frames.is_empty():
					texture = _night_frames[0]
			else:
				texture = _transition_frames[_frame_index]

## Called by GameManager whenever a stage starts. is_night = true kicks off
## the transition (if not already night/transitioning); is_night = false
## snaps straight back to the day loop (no reverse-transition asset exists).
func set_night(is_night: bool) -> void:
	if is_night:
		if _state == State.DAY:
			_state = State.TRANSITIONING
			_frame_index = 0
			_time_accum = 0.0
			if not _transition_frames.is_empty():
				texture = _transition_frames[0]
		# else already NIGHT or mid-TRANSITIONING -- leave it alone.
	else:
		if _state != State.DAY:
			_state = State.DAY
			_frame_index = 0
			_time_accum = 0.0
			if not _day_frames.is_empty():
				texture = _day_frames[0]

func _slice_row(sheet: Texture2D, row: int) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	for c in range(COLUMNS):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(c * FRAME_WIDTH, row * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)
		frames.append(atlas)
	return frames
