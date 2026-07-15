extends ColorRect

@export var grid_row: int 
@export var grid_col: int 
@onready var jeepney_grid = get_tree().root.get_node("Main_Jeepney/JeepneyGridManager")

# Check if the object hovering over this seat is a valid passenger
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("logic_data"):
		var passenger = data["logic_data"]
		if jeepney_grid.can_place_passenger(passenger, grid_row, grid_col):
			return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var passenger_node = data["ui_node"]
	var passenger = data["logic_data"]
	
	# Visually snap the UI to the center of your white square
	var center_offset = (self.size - passenger_node.size) / 2.0
	passenger_node.global_position = self.global_position + center_offset
	
	# Tell backend to occupy the grid slot
	jeepney_grid.place_passenger(passenger, grid_row, grid_col)
	
	# Debug print to verify if working
	print("Success! Passenger seated at Row: ", grid_row, " Col: ", grid_col)
