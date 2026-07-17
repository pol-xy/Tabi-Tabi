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
var _drag_preview: AnimatedSprite2D = null

func _ready():
	_determine_anim_prefix()
	set_standby()

func _process(_delta):
	if is_dragging and _drag_preview:
		# Play directional animations on the PREVIEW (the thing actually
		# following the cursor) rather than the real card, which stays put.
		handle_drag_animations()

# -- INPUT HANDLING --
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Just the "inspect on click" signal now -- dragging itself is
			# handled by _get_drag_data() below, which Godot only calls once
			# an actual drag gesture (movement past a threshold) starts. A
			# plain click no longer force-breaks the card out of the queue.
			card_selected.emit(passenger_data)

# Godot's built-in Control drag-and-drop entry point. This is what seat_1.gd's
# _can_drop_data()/_drop_data() have been waiting for -- without this, seats
# never receive a drop no matter how "correctly" you drag onto them.
#
# IMPORTANT: this does NOT move the real card via top_level/global_position
# anymore. The card lives inside QueuePanel's ScrollContainer, which always
# clips anything outside its own small rect -- moving the real node out of
# that rect (even as top_level) meant it (and possibly its siblings' layout)
# fought with that clipping. Instead we hand Godot a disposable preview via
# set_drag_preview(); Godot moves THAT independently of the scene tree, and
# the real card just sits still (dimmed) until the drop resolves.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_data == null:
		return null

	if is_seated:
		var lift_anim := anim_prefix + "_drop_back" if current_seat_index == 1 else anim_prefix + "_drop_front"
		if anim_sprite.sprite_frames.has_animation(lift_anim):
			anim_sprite.play_backwards(lift_anim)

	is_dragging = true
	is_seated = false
	last_mouse_pos = get_global_mouse_position()

	# set_drag_preview() requires a Control specifically -- AnimatedSprite2D
	# is a Node2D, so it has to be wrapped. The wrapper is what we hand to
	# Godot; _drag_preview keeps pointing at the actual sprite inside it so
	# handle_drag_animations() can still swap its animation each frame.
	var preview_wrapper := Control.new()
	_drag_preview = AnimatedSprite2D.new()
	_drag_preview.sprite_frames = anim_sprite.sprite_frames
	_drag_preview.animation = anim_sprite.animation
	_drag_preview.frame = anim_sprite.frame
	_drag_preview.scale = anim_sprite.scale
	preview_wrapper.add_child(_drag_preview)
	set_drag_preview(preview_wrapper)

	modulate.a = 0.4  # original card dims in place while its preview is dragged

	return {"ui_node": self, "logic_data": passenger_data}

# Fires on EVERY Control when any drag operation ends, success or cancel --
# this is fine here since we only ever touch OUR OWN modulate/state, so it's
# harmless no-op work for cards that weren't the one being dragged.
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		is_dragging = false
		_drag_preview = null
		if not is_seated:
			modulate.a = 1.0
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
	_play_anim(anim_sprite, anim_prefix + "_idle")

# Called by seat_1.gd's _drop_data() after a successful reparent, so the
# blink/drop animation still plays on the real card once it's actually
# sitting in the seat (the preview is gone by this point -- Godot frees it
# automatically once the drag concludes).
func play_seated_animation(seat_number: int):
	_strip_card_chrome()

	var drop_anim := anim_prefix + "_drop_back" if seat_number == 1 else anim_prefix + "_drop_front"
	if anim_sprite.sprite_frames.has_animation(drop_anim):
		anim_sprite.play(drop_anim)
		await anim_sprite.animation_finished
	
	_play_anim(anim_sprite, anim_prefix + "_blink")
	if anim_sprite.sprite_frames.has_animation(anim_prefix + "_blink"):
		await anim_sprite.animation_finished
		
	_play_anim(anim_sprite, anim_prefix + "_idle")

# PassengerCard is a Button, which draws its own background panel by
# default -- that's the intended "card" look while waiting in the queue.
# Once seated though, we just want the sprite standing in the seat, not a
# button-shaped card floating on top of it. Overriding every state with an
# empty stylebox removes that background without touching the sprite.
func _strip_card_chrome():
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("focus", empty)
	add_theme_stylebox_override("disabled", empty)

func restore_card_chrome():
	remove_theme_stylebox_override("normal")
	remove_theme_stylebox_override("hover")
	remove_theme_stylebox_override("pressed")
	remove_theme_stylebox_override("focus")
	remove_theme_stylebox_override("disabled")

func handle_drag_animations():
	var current_pos = get_global_mouse_position()
	last_mouse_pos = current_pos
	
	var anim_name = anim_prefix + "_idle"
	if _drag_preview:
		_play_anim(_drag_preview, anim_name)

func _play_anim(sprite: AnimatedSprite2D, anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		var fallback := anim_prefix + "_idle"
		if sprite.sprite_frames.has_animation(fallback):
			sprite.play(fallback)
		elif sprite.sprite_frames.has_animation("regular_idle"):
			sprite.play("regular_idle")
