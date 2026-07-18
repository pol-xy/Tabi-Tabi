extends Control
## scripts/main_jeepney.gd

@onready var hud := $HUD
@onready var grid_manager := $JeepneyGridManager
@onready var _grid_container := get_node_or_null("Jeepney_BG/GridContainer")
@onready var _bg_sprite := get_node_or_null("Jeepney_BG/BG_Sprite")
@onready var _jeep_exterior := get_node_or_null("Jeepney_BG/JeepExterior")

func _ready() -> void:
	GameManager.register_hud(hud)
	GameManager.register_grid(grid_manager)
	GameManager.register_seat_nodes(_collect_seat_nodes())
	GameManager.register_background(_bg_sprite)
	GameManager.register_jeep_exterior(_jeep_exterior)

	if not grid_manager.dimensions_changed.is_connected(_on_grid_dimensions_changed):
		grid_manager.dimensions_changed.connect(_on_grid_dimensions_changed)

	if not GameManager.campaign_complete.is_connected(_on_campaign_complete):
		GameManager.campaign_complete.connect(_on_campaign_complete)

	GameManager.start_campaign()

func _on_campaign_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main/EndCredits.tscn")

func _on_grid_dimensions_changed(_rows: int, cols: int) -> void:
	var seats = _collect_seat_nodes()
	
	const CABIN_CENTER_X := 210.0
	const SEAT_W         := 64.0   # custom_minimum_size.x of every seat node

	var step_x: float = 0.0
	var row_y_offsets = [0.0, 96.0]

	if cols == 4:
		step_x = 86.0
	else:
		step_x = 74.0

	var total_row_w := (cols - 1) * step_x + SEAT_W
	var start_x     := CABIN_CENTER_X - total_row_w / 2.0

	for seat in seats:
		if seat == null:
			continue
		var r = seat.grid_row
		var c = seat.grid_col
		
		var local_x = start_x + (c * step_x)
		var local_y = row_y_offsets[r]
		seat.position = Vector2(local_x, local_y)

func _collect_seat_nodes() -> Array:
	var seats: Array = []
	if _grid_container:
		for child in _grid_container.get_children():
			seats.append(child)
	return seats
