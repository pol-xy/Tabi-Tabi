extends PanelContainer
## Scripts/UI/tooltip.gd
## Generic hover tooltip. ONE shared instance under HUD, same pattern as
## the dialogue bubble — anything with mouse_entered/mouse_exited can call
## show_tooltip()/hide_tooltip() on this one node. Useful for trait icons
## ("Sweaty — loses happiness near Wet passengers") and rule explanations.

@onready var label: Label = $Margin/Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if visible:
		global_position = get_global_mouse_position() + Vector2(16, 16)

func show_tooltip(text: String) -> void:
	label.text = text
	visible = true

func hide_tooltip() -> void:
	visible = false
