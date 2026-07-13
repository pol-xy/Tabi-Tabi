extends PanelContainer
## Scripts/UI/quota_panel.gd
## Displays current fare earned vs. the stage's target quota.
## Dev 4 dependency: calls set_quota(target) on stage load, then
## add_fare(amount) whenever a passenger is successfully seated and pays.

signal quota_met
signal quota_failed  ## Dev 4 may call check_failed() at stage end instead.

@onready var amount_label: Label = $Margin/VBox/AmountLabel
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressBar

var _current: float = 0.0
var _target: float = 1.0

func set_quota(target: float) -> void:
	_target = max(target, 0.01)
	_current = 0.0
	_refresh()

func add_fare(amount: float) -> void:
	_current += amount
	_refresh()
	if _current >= _target:
		emit_signal("quota_met")

func _refresh() -> void:
	amount_label.text = "₱%d / ₱%d" % [int(_current), int(_target)]
	progress_bar.max_value = _target
	progress_bar.value = _current
