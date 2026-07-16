extends Area2D

############################################################
# seat.gd
#
# Attach this SAME script to:
# Seat01
# Seat02
# ...
# Seat10
############################################################

# ----------------------------------------------------------
# Seat State
# ----------------------------------------------------------

enum SeatState {
	NORMAL,
	AVAILABLE,
	HOVER,
	OCCUPIED
}

# ----------------------------------------------------------
# Inspector Variables
# ----------------------------------------------------------

@export var seat_id: int = 1

# left / right side of jeep
@export_enum("left", "right")
var seat_direction: String = "left"

# ----------------------------------------------------------
# Nodes
# ----------------------------------------------------------

@onready var marker: Marker2D = $Marker2D

@onready var highlight: ColorRect = $ColorRect

# ----------------------------------------------------------
# Variables
# ----------------------------------------------------------

var passenger: Area2D = null

var state := SeatState.NORMAL

# ----------------------------------------------------------
# Ready
# ----------------------------------------------------------

func _ready():

	add_to_group("Seats")

	highlight.visible = false

	update_visual()


# ----------------------------------------------------------
# Passenger
# ----------------------------------------------------------

func can_accept_passenger() -> bool:

	return passenger == null


func assign_passenger(new_passenger: Area2D):

	passenger = new_passenger

	state = SeatState.OCCUPIED

	update_visual()


func remove_passenger():

	passenger = null

	state = SeatState.NORMAL

	update_visual()


func has_passenger() -> bool:

	return passenger != null


# ----------------------------------------------------------
# Marker
# ----------------------------------------------------------

func get_snap_position() -> Vector2:

	return marker.global_position


# ----------------------------------------------------------
# Highlight
# ----------------------------------------------------------

func show_available():

	if passenger != null:
		return

	state = SeatState.AVAILABLE

	update_visual()


func show_hover():

	if passenger != null:
		return

	state = SeatState.HOVER

	update_visual()


func hide_highlight():

	if passenger == null:

		state = SeatState.NORMAL

	else:

		state = SeatState.OCCUPIED

	update_visual()


# ----------------------------------------------------------
# Visual Update
# ----------------------------------------------------------

func update_visual():

	match state:

		SeatState.NORMAL:

			highlight.visible = false

		SeatState.AVAILABLE:

			highlight.visible = true

			highlight.color = Color(0.2, 1.0, 0.2, 0.35)

		SeatState.HOVER:

			highlight.visible = true

			highlight.color = Color(1.0, 1.0, 0.2, 0.45)

		SeatState.OCCUPIED:

			highlight.visible = true

			highlight.color = Color(1.0, 0.2, 0.2, 0.35)


# ----------------------------------------------------------
# Called while dragging over this seat
# ----------------------------------------------------------

func hover():

	show_hover()


func unhover():

	if passenger == null:

		show_available()

	else:

		update_visual()


# ----------------------------------------------------------
# Helper Functions
# ----------------------------------------------------------

func is_priority() -> bool:

	return priority


func is_left() -> bool:

	return seat_direction == "left"


func is_right() -> bool:

	return seat_direction == "right"


# ----------------------------------------------------------
# Debug
# ----------------------------------------------------------

func print_info():

	print("--------------------------------")

	print("Seat ID: ", seat_id)

	print("Priority: ", priority)

	print("Direction: ", seat_direction)

	print("Occupied: ", has_passenger())

	print("--------------------------------")
