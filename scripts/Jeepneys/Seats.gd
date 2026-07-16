extends Node2D

#########################################################
# Seats Manager
#
# Controls all seats inside the jeep.
#
# Does NOT move passengers.
# Does NOT animate passengers.
#
# Only manages seat information.
#########################################################

var seats: Array = []

func _ready():

	load_seats()


#########################################################
# Load every seat inside this node
#########################################################

func load_seats():

	seats.clear()

	for child in get_children():

		if child.is_in_group("Seats"):

			seats.append(child)

	seats.sort_custom(sort_by_id)


#########################################################
# Sort seats by seat_id
#########################################################

func sort_by_id(a, b):

	return a.seat_id < b.seat_id


#########################################################
# Return every seat
#########################################################

func get_all_seats() -> Array:

	return seats


#########################################################
# Return all empty seats
#########################################################

func get_available_seats() -> Array:

	var available := []

	for seat in seats:

		if seat.can_accept_passenger():

			available.append(seat)

	return available


#########################################################
# Return occupied seats
#########################################################

func get_occupied_seats() -> Array:

	var occupied := []

	for seat in seats:

		if !seat.can_accept_passenger():

			occupied.append(seat)

	return occupied


#########################################################
# Return seat by ID
#########################################################

func get_seat(id:int):

	for seat in seats:

		if seat.seat_id == id:

			return seat

	return null


#########################################################
# Return priority seats
#########################################################

func get_priority_seats() -> Array:

	var priority := []

	for seat in seats:

		if seat.priority:

			priority.append(seat)

	return priority


#########################################################
# Highlight every available seat
#########################################################

func highlight_available():

	for seat in seats:

		if seat.can_accept_passenger():

			seat.show_available()


#########################################################
# Remove highlight from every seat
#########################################################

func clear_highlights():

	for seat in seats:

		seat.hide_highlight()


#########################################################
# Highlight hovered seat
#########################################################

func hover_seat(seat):

	if seat == null:
		return

	if seat.can_accept_passenger():

		seat.show_hover()


#########################################################
# Remove hover
#########################################################

func unhover_seat(seat):

	if seat == null:
		return

	if seat.can_accept_passenger():

		seat.show_available()


#########################################################
# Remove passenger from every seat
#########################################################

func clear_all():

	for seat in seats:

		seat.remove_passenger()


#########################################################
# Count occupied seats
#########################################################

func occupied_count() -> int:

	var count := 0

	for seat in seats:

		if !seat.can_accept_passenger():

			count += 1

	return count


#########################################################
# Count empty seats
#########################################################

func available_count() -> int:

	return seats.size() - occupied_count()


#########################################################
# Is jeep full?
#########################################################

func is_full() -> bool:

	return occupied_count() == seats.size()


#########################################################
# Is there at least one seat?
#########################################################

func has_available_seat() -> bool:

	return available_count() > 0


#########################################################
# Find nearest available seat
#########################################################

func get_nearest_available(position:Vector2):

	var nearest = null

	var nearest_distance = INF

	for seat in get_available_seats():

		var distance = position.distance_to(seat.get_snap_position())

		if distance < nearest_distance:

			nearest_distance = distance

			nearest = seat

	return nearest


#########################################################
# Debug
#########################################################

func print_status():

	print("------------------------------------")

	for seat in seats:

		print(
			"Seat ",
			seat.seat_id,
			" | Priority: ",
			seat.priority,
			" | Occupied: ",
			!seat.can_accept_passenger()
		)

	print("------------------------------------")
