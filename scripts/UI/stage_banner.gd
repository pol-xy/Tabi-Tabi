extends CenterContainer
## Scripts/UI/stage_banner.gd
## NOTE: this script wasn't listed under Scripts/UI in the original repo
## plan (only the .tscn was), but the banner needs logic to show/hide/
## animate, so it's included here. Flag this gap to whoever wrote the
## structure doc so it's added to the official list.
##
## Dev 4 dependency: calls show_stage() on stage/level load.
##
## UI PASS (Dev 3): Label moved to $Panel/Margin/Label so the banner can
## sit on a bordered signage panel instead of bare text. Path updated below.

@onready var label: Label = $Panel/Margin/Label

func _ready() -> void:
	modulate.a = 0.0

func show_stage(stage_title: String, hold_seconds: float = 2.0) -> void:
	label.text = stage_title
	visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(hold_seconds)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)
