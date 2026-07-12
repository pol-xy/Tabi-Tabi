class_name JeepneyGrid
extends RefCounted


const ROW_COUNT = 2 # left and right bench
const COL_COUNT = 8 # max n kasya sa bench

# A 2D array representing seats: 2 rows of 8 columns.
# Value is null if empty, or a Passenger reference.
var seats: Array = []

func _init() -> void:
	clear_grid()

# Resets the grid to all nulls.
func clear_grid() -> void:
	seats = []
	for r in range(ROW_COUNT):
		var row_array = []
		for c in range(COL_COUNT):
			row_array.append(null)
		seats.append(row_array)

# Checks if a passenger can be placed at a specific starting position.
func can_place_passenger(passenger: Passenger, row: int, col: int) -> bool:
	if passenger == null:
		return false
	
	# this checks if inside bounds
	if row < 0 or row >= ROW_COUNT:
		return false
	# this also checks if inside bounds
	if col < 0 or col >= COL_COUNT:
		return false

	# Seat size must be at least 1 slot.
	var size = passenger.seat_size_passenger
	if size < 1:
		return false
	# this checks if it doesn't exceed the bench
	if col + size - 1 >= COL_COUNT:
		return false
		
	# this checks if all target cells are empty (or occupied by the passenger themselves)
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
		
	# Remove passenger from old seats if they were already placed
	remove_passenger(passenger)
	
	# Occupy the new seats
	for i in range(passenger.seat_size_passenger):
		seats[row][col + i] = passenger
		
	return true

# Removes all occurrences of a passenger from the grid.
func remove_passenger(passenger: Passenger) -> void:
	if passenger == null:
		return
	for r in range(ROW_COUNT):
		for c in range(COL_COUNT):
			if seats[r][c] == passenger:
				seats[r][c] = null

# Retrieves passenger at specific coordinates.
func get_passenger_at(row: int, col: int) -> Passenger:
	if row < 0 or row >= ROW_COUNT or col < 0 or col >= COL_COUNT:
		return null
	return seats[row][col]

# Returns a unique list of all passengers currently seated.
func get_unique_passengers() -> Array[Passenger]:
	var list: Array[Passenger] = []
	for r in range(ROW_COUNT):
		for c in range(COL_COUNT):
			var passenger = seats[r][c]
			if passenger != null and not list.has(passenger):
				list.append(passenger)
	return list

# Returns coordinates occupied by a passenger as Vector2i(row, col).
func get_occupied_slots(passenger: Passenger) -> Array[Vector2i]:
	var slots: Array[Vector2i] = []
	if passenger == null:
		return slots
		
	for r in range(ROW_COUNT):
		for c in range(COL_COUNT):
			if seats[r][c] == passenger:
				slots.append(Vector2i(r, c))
	return slots

# Returns side-by-side neighbors of a passenger in the same row.
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
	if max_col + 1 < COL_COUNT:
		var right_pass = seats[row][max_col + 1]
		if right_pass != null and right_pass != passenger and not neighbors.has(right_pass):
			neighbors.append(right_pass)
			
	return neighbors

# Helper to debug print the grid.
func print_grid() -> void:
	print("--- JEEPNEY SEATING GRID ---")
	for r in range(ROW_COUNT):
		var row_str = "Row %d: [" % r
		for c in range(COL_COUNT):
			var passenger = seats[r][c]
			if passenger == null:
				row_str += " . "
			else:
				var size_indicator = "=" if passenger.seat_size_passenger > 1 else ""
				row_str += " %s%s%s " % [size_indicator, passenger.id.substr(0, min(3, passenger.id.length())), size_indicator]
			if c < COL_COUNT - 1:
				row_str += "|"
		row_str += "]"
		print(row_str)
	print("----------------------------")
