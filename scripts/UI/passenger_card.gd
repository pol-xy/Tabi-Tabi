class_name PassengerCard
extends Button # Or Control, matching your root node

signal card_selected(passenger)

@onready var anim_sprite = $AnimatedSprite2D

var passenger_data 
var anim_prefix: String = "regular"
var is_active: bool = false 

var is_dragging: bool = false
var is_seated: bool = false
var was_seated: bool = false  ## Preserved across _get_drag_data so seat_1.gd can detect swaps
var current_seat_index: int = -1
var _seat_anim_id: int = 0  ## Incremented on every play_seated_animation call; stale coroutines check this and abort

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

	was_seated = is_seated  # Preserve before clearing so seat_1.gd swap detection works

	if is_seated:
		# Play the drop animation BACKWARDS so the passenger visually rises off the seat
		var lift_anim: String
		if current_seat_index == 0:
			lift_anim = anim_prefix + "_drop_front"
		else:
			lift_anim = anim_prefix + "_drop_back"
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

# --- Drop forwarding for seated cards -------------------------------------------
# PassengerCard is a Button (mouse_filter=STOP), so when a card is seated inside a
# seat_1.gd ColorRect, it sits on TOP and Godot's DND hit-test stops here.
# The parent seat never gets to run its own _can_drop_data/_drop_data which means
# dragging onto an occupied seat (for swapping) silently fails.
# Forwarding the calls to the parent seat fixes this transparently.

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_seated:
		return false  # Card is in queue — queue_panel handles its own drops
	var parent_seat = get_parent()
	if parent_seat and parent_seat.has_method("_can_drop_data"):
		return parent_seat._can_drop_data(_at_position, data)
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not is_seated:
		return
	var parent_seat = get_parent()
	if parent_seat and parent_seat.has_method("_drop_data"):
		parent_seat._drop_data(_at_position, data)

# Fires on EVERY Control when any drag operation ends, success or cancel --
# this is fine here since we only ever touch OUR OWN modulate/state, so it's
# harmless no-op work for cards that weren't the one being dragged.
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		is_dragging = false
		_drag_preview = null
		if not is_seated:
			modulate.a = 1.0
			# If drag was cancelled OR drop handlers didn't re-mark us as seated,
			# but we originally came FROM a seat → restore proper seated pose.
			if was_seated and current_seat_index >= 0:
				is_seated = true
				play_seated_animation(current_seat_index)
			else:
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
	elif passenger_data.get("is_companion"):
		# Lovey Dovey couples: lover_a → couple_1 sprite, lover_b → couple_2 sprite.
		var pid_val = passenger_data.get("id")
		var pid: String = pid_val if pid_val != null else ""
		if pid.ends_with("_b") or pid.ends_with("lover_b"):
			anim_prefix = "couple_2"
		else:
			anim_prefix = "couple_1"
	elif passenger_data.get("is_balikbayan"):
		# Balikbayan uses market_goer sprite (closest available) until a
		# dedicated balikbayan scene is delivered by the UI/UX team.
		anim_prefix = "market_goer"
	elif passenger_data.get("is_heavy_load"):
		anim_prefix = "market_goer"
	elif passenger_data.get("is_parent_baby"):
		anim_prefix = "parent_baby"
	else:
		anim_prefix = "regular"

# -- STATE CONTROLLERS --
func set_standby():
	is_dragging = false
	is_seated = false
	was_seated = false  ## Always clear: a standby card is a queue card, never "was seated"
	_play_anim(anim_sprite, anim_prefix + "_idle")

# Called by seat_1.gd's _drop_data() after a successful reparent, so the
# blink/drop animation still plays on the real card once it's actually
# sitting in the seat (the preview is gone by this point -- Godot frees it
# automatically once the drag concludes).
func play_seated_animation(grid_row: int):
	_strip_card_chrome()
	current_seat_index = grid_row  # Store for lift animation reference later

	# Bump the generation ID so any previously-running coroutine of this
	# function knows it's been superseded and should abort before touching
	# the animation state again (e.g. old row-0 coroutine's _idle tail would
	# otherwise overwrite a freshly-applied row-1 nakatalikod pose).
	_seat_anim_id += 1
	var my_id := _seat_anim_id

	if grid_row == 0:
		# Upper/front bench → nakaharap sa driver → play _drop_front then settle in _idle
		var drop_anim := anim_prefix + "_drop_front"
		if anim_sprite.sprite_frames.has_animation(drop_anim):
			anim_sprite.play(drop_anim)
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return  # A newer seating call superseded us — abort

		var blink_anim := anim_prefix + "_blink"
		if anim_prefix == "white_lady":
			blink_anim = "white_lady_lady_blink"

		_play_anim(anim_sprite, blink_anim)
		if anim_sprite.sprite_frames.has_animation(blink_anim):
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return  # A newer seating call superseded us — abort

		_play_anim(anim_sprite, anim_prefix + "_idle")
	else:
		# Lower/back bench → nakatalikod → play _drop_back then STOP on last frame
		# (Do NOT call _idle after this or they'll turn to face forward again)
		var drop_anim := anim_prefix + "_drop_back"
		if anim_sprite.sprite_frames.has_animation(drop_anim):
			anim_sprite.play(drop_anim)
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return  # A newer seating call superseded us — abort
		# Stay on last frame of _drop_back = nakatalikod ✅

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
