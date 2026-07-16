extends ProgressBar
## Scripts/UI/anger_bar.gd
## One instance per passenger who needs an Anger Meter (queue slot or
## seated-but-unhappy passenger — confirm with team which contexts need one).
##
## Confirmed against Dev 1's scripts/passenger.gd: anger_meter_max (float,
## default 60.0) matches exactly, no changes needed here.
## Dev 4 dependency: connect to `depleted` to trigger the "1-2-3" penalty.

signal depleted

const COLOR_OK := Color(0.30, 0.75, 0.35)
const COLOR_WARNING := Color(0.95, 0.75, 0.20)
const COLOR_CRITICAL := Color(0.85, 0.20, 0.20)

const WARNING_THRESHOLD := 0.5
const CRITICAL_THRESHOLD := 0.2

const BORDER_INK := Color(0.227, 0.153, 0.094, 1)

var _tick_rate: float = 1.0
var _is_active: bool = false
var _flash_tween: Tween
var _fill_style: StyleBoxFlat

func _ready() -> void:
	_fill_style = StyleBoxFlat.new()
	_fill_style.set_corner_radius_all(5)
	_fill_style.set_border_width_all(2)
	_fill_style.border_color = BORDER_INK
	add_theme_stylebox_override("fill", _fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.227, 0.153, 0.094, 0.3)
	bg_style.set_corner_radius_all(5)
	add_theme_stylebox_override("background", bg_style)

	_update_color()

func _process(delta: float) -> void:
	if not _is_active:
		return
	value -= _tick_rate * delta
	_update_color()
	if value <= 0.0:
		value = 0.0
		_is_active = false
		emit_signal("depleted")

func start_from_passenger(passenger: Passenger) -> void:
	start(passenger.anger_meter_max)

func start(new_max: float, tick_rate: float = 1.0) -> void:
	max_value = new_max
	value = new_max
	_tick_rate = tick_rate
	_is_active = true
	_update_color()

func pause() -> void:
	_is_active = false

func resume() -> void:
	_is_active = true

func _update_color() -> void:
	var val_ratio := value / max_value if max_value > 0 else 0.0
	var bar_color: Color
	if val_ratio <= CRITICAL_THRESHOLD:
		bar_color = COLOR_CRITICAL
		_start_flash()
	elif val_ratio <= WARNING_THRESHOLD:
		bar_color = COLOR_WARNING
		_stop_flash()
	else:
		bar_color = COLOR_OK
		_stop_flash()
	_fill_style.bg_color = bar_color

func _start_flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		return
	_flash_tween = create_tween().set_loops()
	_flash_tween.tween_property(self, "modulate:a", 0.4, 0.25)
	_flash_tween.tween_property(self, "modulate:a", 1.0, 0.25)

func _stop_flash() -> void:
	if _flash_tween:
		_flash_tween.kill()
	modulate.a = 1.0
