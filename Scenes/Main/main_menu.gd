extends Control

func _ready() -> void:
	%PlayButton.grab_focus()

func _on_play_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	get_tree().change_scene_to_file("res://Scenes/Level Selector/Level_Select.tscn")

func _on_quit_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	if get_tree():
		get_tree().quit()
