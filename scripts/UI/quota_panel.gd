extends PanelContainer
## Scripts/UI/quota_panel.gd
## REPURPOSED (v2): displays the stage's countdown timer instead of a fare
## quota, now that the Daily Quota system is retired. Kept at this file
## path and node structure on purpose (PanelContainer > Margin > VBox >
## QuotaLabel/AmountLabel/ProgressBar) so no .tscn changes were needed --
## just the meaning of the numbers changed.
##
## Dev 4 dependency: calls start_timer(seconds) on stage load, then
## update_time(seconds_remaining) every frame via HUD.update_timer().

signal time_up

@onready var header_label: Label = $Margin/VBox/QuotaLabel
@onready var amount_label: Label = $Margin/VBox/AmountLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressBar

const WARNING_COLOR := Color(0.776, 0.180, 0.165, 1)

var _time_limit: float = 1.0
var _time_remaining: float = 0.0
var _fired_time_up: bool = false

func _ready() -> void:
	header_label.text = "ORAS NA NATITIRA"  # "Time Remaining"

func start_timer(time_limit_sec: float) -> void:
	_time_limit = max(time_limit_sec, 0.01)
	_time_remaining = _time_limit
	_fired_time_up = false
	_refresh()

func update_time(seconds_remaining: float) -> void:
	_time_remaining = max(seconds_remaining, 0.0)
	_refresh()
	if _time_remaining <= 0.0 and not _fired_time_up:
		_fired_time_up = true
		emit_signal("time_up")

func _refresh() -> void:
	var minutes := int(_time_remaining) / 60
	var seconds := int(_time_remaining) % 60
	amount_label.text = "%d:%02d" % [minutes, seconds]
	progress_bar.max_value = _time_limit
	progress_bar.value = _time_remaining
	if _time_remaining <= _time_limit * 0.2:
		amount_label.add_theme_color_override("font_color", WARNING_COLOR)
	else:
		amount_label.remove_theme_color_override("font_color")
