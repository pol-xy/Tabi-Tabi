class_name PassengerCard
extends Button # Or Control, matching your root node

signal card_selected(passenger)

@onready var anim_sprite = $AnimatedSprite2D

var passenger_data 
var anim_prefix: String = "regular"
var is_active: bool = false 

var is_dragging: bool = false
var is_seated: bool = false
var current_seat_index: int = -1

var last_mouse_pos: Vector2
var drag_offset: Vector2 = Vector2.ZERO # Keeps the mouse from snapping to the top-left corner

func _ready():
	_determine_anim_prefix()
	set_standby()

func _process(_delta):
	if is_dragging:
		# 1. Actually move the card to follow the mouse
		global_position = get_global_mouse_position() + drag_offset
		# 2. Play the directional animations
		handle_drag_animations()

# -- INPUT HANDLING --
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			card_selected.emit(passenger_data)
			start_drag()
		else:
			is_dragging = false
			
			if not is_seated:
				set_as_top_level(false)
				set_standby()

# -- DATA PARSING --
func _determine_anim_prefix():
	if passenger_data == null:
		return
		
	if passenger_data.get("is_jb_suarez") or passenger_data.get("passenger_name") == "JB Suarez":
		anim_prefix = "jb_suarez"
	elif passenger_data.get("is_white_lady") or passenger_data.get("passenger_name") == "White Lady":
		anim_prefix = "white_lady"
	elif passenger_data.get("is_student"):
		anim_prefix = "student"
	elif passenger_data.get("is_employee"):
		anim_prefix = "employee"
	elif passenger_data.get("is_senior"):
		anim_prefix = "senior"
	elif passenger_data.get("is_pregnant"):
		anim_prefix = "pregnant"
	elif passenger_data.get("is_pwd"):
		anim_prefix = "pwd"
	elif passenger_data.get("is_heavy_load"): 
		anim_prefix = "market_goer"
	elif passenger_data.get("is_parent_baby"):
		anim_prefix = "parent_baby"
	elif passenger_data.get("is_lovey_dovey"): 
		anim_prefix = "lovey_dovey"
	else:
		anim_prefix = "regular"

# -- STATE CONTROLLERS --
func set_standby():
	is_dragging = false
	is_seated = false
	anim_sprite.play(anim_prefix + "_idle")

func start_drag():
	is_dragging = true
	is_seated = false
	last_mouse_pos = get_global_mouse_position()
	drag_offset = global_position - last_mouse_pos
	
	# Break free from the HBoxContainer so we can move around the screen
	set_as_top_level(true)
	z_index = 100 # Bring to the front

func seat_passenger(seat_number: int):
	is_dragging = false
	is_seated = true
	current_seat_index = seat_number
	
	print("SUCCESS: passenger card registered drop on seat ", seat_number)
	
	# 1. Delay the coordinate reset until seat_1.gd finishes reparenting
	call_deferred("_snap_to_seat")
	
	anim_sprite.play(anim_prefix + "_blink")
	await anim_sprite.animation_finished
	
	if seat_number >= 5 and seat_number <= 10:
		anim_sprite.play(anim_prefix + "_drop_back")
	else:
		anim_sprite.play(anim_prefix + "_drop_front")

# Create this new helper function right beneath seat_passenger:
func _snap_to_seat():
	set_as_top_level(false)
	position = Vector2.ZERO
	# 2. Force the sprite to draw in front of the Jeepney body
	z_index = 10

func handle_drag_animations():
	var current_pos = get_global_mouse_position()
	var velocity = current_pos - last_mouse_pos
	last_mouse_pos = current_pos
	
	if velocity.length() < 1.0:
		return 
		
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			anim_sprite.play(anim_prefix + "_drag_right")
		else:
			anim_sprite.play(anim_prefix + "_drag_left")
	else:
		if velocity.y > 0:
			anim_sprite.play(anim_prefix + "_drag_down")
		else:
			anim_sprite.play(anim_prefix + "_drag_up")
