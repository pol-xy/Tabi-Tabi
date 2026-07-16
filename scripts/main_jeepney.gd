extends Control
## scripts/main_jeepney.gd
## Attached to Main_Jeepney.tscn's root node. Its only job is to hand the
## HUD and JeepneyGrid over to the GameManager autoload once the scene is
## actually ready, then kick off the campaign. Keeps GameManager itself
## scene-agnostic (easier to unit-test, easier to reuse if the scene gets
## restructured later).

@onready var hud := $HUD
@onready var grid_manager := $JeepneyGridManager

func _ready() -> void:
	GameManager.register_hud(hud)
	GameManager.register_grid(grid_manager)
	GameManager.register_seat_nodes(_collect_seat_nodes())
	GameManager.start_campaign()

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
