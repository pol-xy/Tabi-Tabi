extends Control
## scripts/UI/game_over_popup.gd

signal retry_pressed

@onready var retry_button = %RetryButton

func _ready() -> void:
	visible = false

func show_popup() -> void:
	visible = true
	# Pause the game tree so the timer/movement stops, but this node still processes
	get_tree().paused = true
	retry_button.grab_focus()

func hide_popup() -> void:
	visible = false
	get_tree().paused = false

func _on_retry_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	hide_popup()
	emit_signal("retry_pressed")

func _on_quit_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	hide_popup()
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")
