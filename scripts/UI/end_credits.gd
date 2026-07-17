extends Control
## scripts/UI/end_credits.gd

func _ready() -> void:
	%BackButton.grab_focus()

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")
