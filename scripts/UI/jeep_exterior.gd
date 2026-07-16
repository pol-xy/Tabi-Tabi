class_name JeepExterior
extends TextureRect
## scripts/UI/jeep_exterior.gd
## Purely decorative jeep exterior art -- NOT the gameplay seat/passenger
## system. That job stays with seat_1.gd + JeepneyGridManager, same as
## every other part of the real game. This just loops one of the 6 jeep
## liveries' idle animation behind/around the seat grid, matching whichever
## variant the active level specifies.
##
## Deliberately does NOT reuse Scenes/Jeepneys/jeep_1.tscn (etc.) directly --
## those scenes come bundled with jeep_1.gd's own independent Seats/
## PassengerContainer drag-and-drop system, which has no connection to
## RuleValidator/GameManager. Loading the raw frame textures here instead
## keeps the art without pulling in that parallel gameplay implementation.
##
## Frame files: Assets/Sprites/Jeepneys/Jeep{variant}/frame_{0..4}_delay-0.1s.png
## Usage: GameManager.register_jeep_exterior(this_node), then call
## set_variant(1..6) whenever a level starts (see game_manager.gd's
## _apply_jeep_exterior, called once per level from _advance_level).

const FRAME_COUNT := 5

@export var frames_per_second: float = 6.0

var _variant: int = -1
var _frames: Array[Texture2D] = []
var _frame_index: int = 0
var _time_accum: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if frames_per_second <= 0.0 or _frames.is_empty():
		return
	_time_accum += delta
	var frame_duration := 1.0 / frames_per_second
	if _time_accum < frame_duration:
		return
	_time_accum -= frame_duration
	_frame_index = (_frame_index + 1) % _frames.size()
	texture = _frames[_frame_index]

## Called by GameManager once per level. No-op if already showing this
## variant, so it's safe to call even if something calls it more than once.
func set_variant(variant: int) -> void:
	if variant == _variant:
		return
	_variant = variant
	_frames.clear()
	for i in range(FRAME_COUNT):
		var path := "res://Assets/Sprites/Jeepneys/Jeep%d/frame_%d_delay-0.1s.png" % [variant, i]
		var tex: Texture2D = load(path)
		if tex:
			_frames.append(tex)
		else:
			push_warning("JeepExterior: missing %s (check the variant number and folder name)" % path)
	_frame_index = 0
	_time_accum = 0.0
	if not _frames.is_empty():
		texture = _frames[0]
