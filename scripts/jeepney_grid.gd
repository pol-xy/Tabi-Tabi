class_name JeepneyGrid
extends Node

# SIGNAL ADDED: Connect this to your UI script to dynamically update GridContainer.columns
signal dimensions_changed(rows: int, cols: int)

var row_count: int = 2
var col_count: int = 5 # Default is 5, but will change dynamically

var seats: Array = []

func _init(p_rows: int = 2, p_cols: int = 5) -> void:
	row_count = p_rows
	col_count = p_cols
	clear_grid()

# Changes the grid's row/col count for a new level (e.g. 8-seater vs 10-seater)
func set_dimensions(p_rows: int, p_cols: int) -> void:
	row_count = p_rows
	col_count = p_cols
	clear_grid()
	# Emit signal so the UI knows to update GridContainer.columns
	dimensions_changed.emit(row_count, col_count)

# Resets the grid to all nulls.
func clear_grid() -> void:
	seats = []
	for r in range(row_count):
		var row_array = []
		for c in range(col_count):
			row_array.append(null)
		seats.append(row_array)

# Checks if a passenger can be placed at a specific starting position.
func can_place_passenger(passenger: Passenger, row: int, col: int) -> bool:
	if passenger == null:
		return false
	
	if row < 0 or row >= row_count:
		return false
	if col < 0 or col >= col_count:
		return false

	var size = passenger.seat_size_passenger
	if size < 1:
		return false
	if col + size - 1 >= col_count:
		return false
		
	for i in range(size):
		var check_col = col + i
		var current_occupant = seats[row][check_col]
		if current_occupant != null and current_occupant != passenger:
			return false
			
	return true

# Places a passenger at a starting position. Returns true if successful.
func place_passenger(passenger: Passenger, row: int, col: int) -> bool:
	if not can_place_passenger(passenger, row, col):
		return false
		
	remove_passenger(passenger)
	
	for i in range(passenger.seat_size_passenger):
		seats[row][col + i] = passenger
		
	return true

# Removes all occurrences of a passenger from the grid.
func remove_passenger(passenger: Passenger) -> void:
	if passenger == null:
		return
	for r in range(row_count):
		for c in range(col_count):
			if seats[r][c] == passenger:
				seats[r][c] = null

# Retrieves passenger at specific coordinates.
func get_passenger_at(row: int, col: int) -> Passenger:
	if row < 0 or row >= row_count or col < 0 or col >= col_count:
		return null
	return seats[row][col]

# Returns a unique list of all passengers currently seated.
func get_unique_passengers() -> Array[Passenger]:
	var list: Array[Passenger] = []
	for r in range(row_count):
		for c in range(col_count):
			var passenger = seats[r][c]
			if passenger != null and not list.has(passenger):
				list.append(passenger)
	return list

# Returns coordinates occupied by a passenger as Vector2i(row, col).
func get_occupied_slots(passenger: Passenger) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	if passenger == null:
		return slots
		
	for r in range(row_count):
		for c in range(col_count):
			if seats[r][c] == passenger:
				slots.append(Vector2i(r, c))
	return slots

# Returns side-by-side AND across the aisle neighbors of a passenger.
func get_adjacent_neighbors(passenger: Passenger) -> Array[Passenger]:
	var neighbors: Array[Passenger] = []
	var slots = get_occupied_slots(passenger)
	if slots.is_empty():
		return neighbors
		
	var row = slots[0].x
	var min_col = slots[0].y
	var max_col = slots[slots.size() - 1].y
	
	# Check left neighbor
	if min_col - 1 >= 0:
		var left_pass = seats[row][min_col - 1]
		if left_pass != null and left_pass != passenger:
			neighbors.append(left_pass)
			
	# Check right neighbor
	if max_col + 1 < col_count:
		var right_pass = seats[row][max_col + 1]
		if right_pass != null and right_pass != passenger and not neighbors.has(right_pass):
			neighbors.append(right_pass)
			
	# FIX: Check Katapat (Across the aisle)
	var across_row = 1 if row == 0 else 0
	if across_row < row_count:
		for c in range(min_col, max_col + 1):
			var across_pass = seats[across_row][c]
			if across_pass != null and across_pass != passenger and not neighbors.has(across_pass):
				neighbors.append(across_pass)
			
	return neighbors

# Helper to debug print the grid.
func print_grid() -> void:
	print("--- JEEPNEY SEATING GRID ---")
	for r in range(row_count):
		var row_str = "Row %d: [" % r
		for c in range(col_count):
			var passenger = seats[r][c]
			if passenger == null:
				row_str += " . "
			else:
				var size_indicator = "=" if passenger.seat_size_passenger > 1 else ""
				row_str += " %s%s%s " % [size_indicator, passenger.id.substr(0, min(3, passenger.id.length())), size_indicator]
			if c < col_count - 1:
				row_str += "|"
		row_str += "]"
		print(row_str)
	print("----------------------------")
