extends Control
## scripts/UI/pause_menu.gd

signal pause_toggled(is_paused: bool)

@onready var master_slider = %MasterSlider
@onready var bgm_slider = %BGMSlider
@onready var sfx_slider = %SFXSlider
@onready var resume_button = %ResumeButton

func _ready() -> void:
	visible = false
	
	# Initialize sliders with current bus volumes
	master_slider.value = _get_bus_volume("Master")
	bgm_slider.value = _get_bus_volume("BGM")
	sfx_slider.value = _get_bus_volume("SFX")
	
	# Connect slider signals
	master_slider.value_changed.connect(_on_master_slider_changed)
	bgm_slider.value_changed.connect(_on_bgm_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)

func toggle_pause() -> void:
	var is_paused = !get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused
	pause_toggled.emit(is_paused)
	
	if is_paused:
		resume_button.grab_focus()

func _get_bus_volume(bus_name: String) -> float:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var db = AudioServer.get_bus_volume_db(bus_index)
		if db <= -79.0:
			return 0.0
		return db_to_linear(db)
	return 1.0

func _set_bus_volume(bus_name: String, linear_value: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index != -1:
		var db = linear_to_db(linear_value)
		if linear_value <= 0.05:
			db = -80.0
		AudioServer.set_bus_volume_db(bus_index, db)

func _on_master_slider_changed(value: float) -> void:
	_set_bus_volume("Master", value)

func _on_bgm_slider_changed(value: float) -> void:
	_set_bus_volume("BGM", value)

func _on_sfx_slider_changed(value: float) -> void:
	_set_bus_volume("SFX", value)

func _on_resume_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	toggle_pause()

func _on_quit_button_pressed() -> void:
	GameManager.play_sfx("click_select")
	get_tree().paused = false
	visible = false
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")
