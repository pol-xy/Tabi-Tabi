extends Control
## scripts/UI/level_completion_popup.gd

signal continue_pressed

@onready var title_label = %LevelTitleLabel
@onready var continue_button = %ContinueButton

func _ready() -> void:
	visible = false

func show_popup(level_title: String) -> void:
	title_label.text = level_title + " cleared!"
	visible = true
	continue_button.grab_focus()
	# Optional: play popup animation or sound here if needed

func hide_popup() -> void:
	visible = false

func _on_continue_button_pressed() -> void:
	hide_popup()
	emit_signal("continue_pressed")
