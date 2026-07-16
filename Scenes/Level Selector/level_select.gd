extends Control

func _ready() -> void:
	%Level1.grab_focus()

func _on_level_1_button_pressed() -> void:
	GameManager.current_level_index = 0
	get_tree().change_scene_to_file("res://Scenes/Main_Jeepney.tscn")

func _on_level_2_pressed() -> void:
	GameManager.current_level_index = 1
	get_tree().change_scene_to_file("res://Scenes/Main_Jeepney.tscn")
	
func _on_level_3_pressed() -> void:
	GameManager.current_level_index = 2
	get_tree().change_scene_to_file("res://Scenes/Main_Jeepney.tscn")
