extends ColorRect

@export var grid_row: int 
@export var grid_col: int 

# Check if the object hovering over this seat is a valid passenger
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("ui_node"):
		# Later, you will call Dev 1's `can_place_passenger` here
		return true 
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	var passenger_node = data["ui_node"]
	
	var center_offset = (self.size - passenger_node.size) / 2.0
	passenger_node.global_position = self.global_position + center_offset
	
	# Print a debug message to prove your coordinates work
	print("Success! Passenger seated at Row: ", grid_row, " Col: ", grid_col)
