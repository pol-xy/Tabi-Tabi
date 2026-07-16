extends Control

func _ready() -> void:
	%PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/LevelSelect.tscn")

func _on_quit_button_pressed() -> void:
	if get_tree():
		get_tree().quit()
