extends ColorRect

@export var grid_row: int 
@export var grid_col: int 
@onready var jeepney_grid = get_tree().root.get_node("Main_Jeepney/JeepneyGridManager")

# Check if the object hovering over this seat is a valid passenger
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.has("logic_data"):
		var passenger = data["logic_data"]
		if jeepney_grid.can_place_passenger(passenger, grid_row, grid_col):
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var passenger_node = data["ui_node"]
	var passenger = data["logic_data"]

	# Reparent the card out of the QueuePanel's ScrollContainer/HBoxContainer
	# and into this seat. Just setting global_position wasn't enough --
	# the ScrollContainer clips anything outside its own visible rect, and
	# the HBoxContainer re-asserts its row layout on re-sort, so the card
	# was getting clipped/snapped back invisibly while still parented there.
	var old_parent = passenger_node.get_parent()
	if old_parent:
		old_parent.remove_child(passenger_node)
	add_child(passenger_node)

	# The card only ever dimmed itself during the drag (a disposable preview
	# handled the on-screen movement) -- restore full opacity now that it's
	# actually landing somewhere, and mark it seated so it doesn't reset
	# itself back to standby.
	passenger_node.is_seated = true
	passenger_node.modulate.a = 1.0
	passenger_node.z_index = 10

	# Now that this seat is its parent, a local (not global) offset centers it.
	passenger_node.position = (self.size - passenger_node.size) / 2.0

	passenger_node.play_seated_animation(grid_row * jeepney_grid.col_count + grid_col)

	# Tell backend to occupy the grid slot
	jeepney_grid.place_passenger(passenger, grid_row, grid_col)

	# Tell Dev 4's GameManager so it can run validation, award fare, and
	# check the stage quota. (This also detaches the card from the queue's
	# own bookkeeping, since it's no longer waiting in line.)
	GameManager.on_passenger_seated(passenger)

	# Debug print to verify if working
	print("Success! Passenger seated at Row: ", grid_row, " Col: ", grid_col)
