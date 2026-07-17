extends Control
## scripts/main_jeepney.gd
## Attached to Main_Jeepney.tscn's root node. Its only job is to hand the
## HUD and JeepneyGrid over to the GameManager autoload once the scene is
## actually ready, then kick off the campaign. Keeps GameManager itself
## scene-agnostic (easier to unit-test, easier to reuse if the scene gets
## restructured later).

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

	# Keep GridContainer.columns in sync with the active level's grid shape
	# (e.g. 4 for an 8-seater 2x4 level, 5 for a 10-seater 2x5 level).
	# Without this, GridContainer only sees the count of *visible* children
	# and wraps using its scene-default `columns`, which misaligns rows
	# whenever a level's column count differs from that default.
	if not grid_manager.dimensions_changed.is_connected(_on_grid_dimensions_changed):
		grid_manager.dimensions_changed.connect(_on_grid_dimensions_changed)

	if not GameManager.campaign_complete.is_connected(_on_campaign_complete):
		GameManager.campaign_complete.connect(_on_campaign_complete)

	GameManager.start_campaign()

func _on_campaign_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main/MainMenu.tscn")

func _on_grid_dimensions_changed(_rows: int, cols: int) -> void:
	var seats = _collect_seat_nodes()
	
	var start_x: float = 0.0
	var step_x: float = 0.0
	var row_y_offsets = [0.0, 96.0]
	
	if cols == 4:
		# 8-seater layout (columns = 4)
		start_x = 100.0
		step_x = 88.0
	else:
		# 10-seater layout (columns = 5, tighter spacing to fit cabin)
		# Changing start_x to 90.0 shifts the seats right by one column, aligning perfectly with the blue cushions
		start_x = 90.0
		step_x = 76.0

	for seat in seats:
		if seat == null:
			continue
		var r = seat.grid_row
		var c = seat.grid_col
		
		var local_x = start_x + (c * step_x)
		var local_y = row_y_offsets[r]
		seat.position = Vector2(local_x, local_y)

## Seats are the ColorRect nodes running seat_1.gd, found under
## Jeepney_BG/GridContainer. Collected generically (by script, not by name)
## so this keeps working if seats are renamed/added later.
func _collect_seat_nodes() -> Array:
	var seats: Array = []
	if _grid_container:
		for child in _grid_container.get_children():
			seats.append(child)
	return seats
