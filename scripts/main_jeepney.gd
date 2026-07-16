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

func _ready() -> void:
	GameManager.register_hud(hud)
	GameManager.register_grid(grid_manager)
	GameManager.register_seat_nodes(_collect_seat_nodes())
	GameManager.register_background(_bg_sprite)

	# Keep GridContainer.columns in sync with the active level's grid shape
	# (e.g. 4 for an 8-seater 2x4 level, 5 for a 10-seater 2x5 level).
	# Without this, GridContainer only sees the count of *visible* children
	# and wraps using its scene-default `columns`, which misaligns rows
	# whenever a level's column count differs from that default.
	if not grid_manager.dimensions_changed.is_connected(_on_grid_dimensions_changed):
		grid_manager.dimensions_changed.connect(_on_grid_dimensions_changed)

	GameManager.start_campaign()

func _on_grid_dimensions_changed(_rows: int, cols: int) -> void:
	if _grid_container:
		_grid_container.columns = cols

## Seats are the ColorRect nodes running seat_1.gd, found under
## Jeepney_BG/GridContainer. Collected generically (by script, not by name)
## so this keeps working if seats are renamed/added later.
func _collect_seat_nodes() -> Array:
	var seats: Array = []
	var grid_container := get_node_or_null("Jeepney_BG/GridContainer")
	if grid_container:
		for child in grid_container.get_children():
			seats.append(child)
	return seats
