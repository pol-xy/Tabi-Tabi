extends Node2D

#########################################################
# Jeep 01
# Controls the jeep scene only.
# Does NOT control passengers.
#########################################################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var seats: Node2D = $Seats
@onready var passenger_container: Node2D = $PassengerContainer

var seat_list: Array = []

func _ready():

	load_seats()

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")


#########################################################
# Load every Seat inside Seats/
#########################################################

func load_seats():

	seat_list.clear()

	for child in seats.get_children():

		if child.is_in_group("Seats"):

			seat_list.append(child)


#########################################################
# Return all seats
#########################################################

func get_all_seats() -> Array:

	return seat_list


#########################################################
# Return only available seats
#########################################################

func get_available_seats() -> Array:

	var available := []

	for seat in seat_list:

		if seat.can_accept_passenger():

			available.append(seat)

	return available


#########################################################
# Highlight all empty seats
#########################################################

func show_available_seats():

	for seat in seat_list:

		if seat.can_accept_passenger():

			seat.show_available()


#########################################################
# Remove all highlights
#########################################################

func hide_available_seats():

	for seat in seat_list:

		seat.hide_highlight()


#########################################################
# Find a seat by ID
#########################################################

func get_seat_by_id(id: int):

	for seat in seat_list:

		if seat.seat_id == id:

			return seat

	return null


#########################################################
# Clear every seat
#########################################################

func clear_all_seats():

	for seat in seat_list:

		seat.remove_passenger()


#########################################################
# Number of occupied seats
#########################################################

func occupied_count() -> int:

	var count := 0

	for seat in seat_list:

		if !seat.can_accept_passenger():

			count += 1

	return count


#########################################################
# Number of free seats
#########################################################

func free_count() -> int:

	return seat_list.size() - occupied_count()


#########################################################
# Returns true if every seat is occupied
#########################################################

func is_full() -> bool:

	return occupied_count() == seat_list.size()


#########################################################
# Returns true if there is at least one free seat
#########################################################

func has_available_seat() -> bool:

	return occupied_count() < seat_list.size()


#########################################################
# Passenger Container helper
#########################################################

func add_passenger(passenger: Node):

	if passenger.get_parent() != passenger_container:

		passenger.reparent(passenger_container)


#########################################################
# Remove passenger from container
#########################################################

func remove_passenger(passenger: Node):

	if passenger.get_parent() == passenger_container:

		passenger.reparent(get_tree().current_scene)


#########################################################
# Debug
#########################################################

func print_seats():

	print("--------------------------------")

	for seat in seat_list:

		print(
			"Seat ",
			seat.seat_id,
			" | Occupied: ",
			!seat.can_accept_passenger()
		)

	print("--------------------------------")
