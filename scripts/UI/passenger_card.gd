class_name PassengerCard
extends Button 

signal card_selected(passenger)

const OverheadEmoteScene := preload("res://Scenes/UI(2)/overhead_emotes.tscn")

@onready var anim_sprite = $AnimatedSprite2D

var passenger_data 
var anim_prefix: String = "regular"
var is_active: bool = false 

var is_dragging: bool = false
var is_seated: bool = false
var was_seated: bool = false  # Preserved across _get_drag_data so seat_1.gd can detect swaps
var current_seat_index: int = -1
var _seat_anim_id: int = 0  # Incremented on every play_seated_animation call

var last_mouse_pos: Vector2
var _drag_preview: AnimatedSprite2D = null

var _feedback_emote: Node2D = null
var _feedback_tween: Tween = null

func _ready():
	_determine_anim_prefix()
	set_standby()

func _process(_delta):
	if is_dragging and _drag_preview:
		handle_drag_animations()

# --- Input handling ---
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			card_selected.emit(passenger_data)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if passenger_data == null:
		return null

	GameManager.play_sfx("drag_passenger")
	was_seated = is_seated  # Preserve before clearing so seat_1.gd swap detection works

	if is_seated:
		# Play the reverse drop animation
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

	var preview_wrapper := Control.new()
	_drag_preview = AnimatedSprite2D.new()
	_drag_preview.sprite_frames = anim_sprite.sprite_frames
	_drag_preview.animation = anim_sprite.animation
	_drag_preview.frame = anim_sprite.frame
	_drag_preview.scale = anim_sprite.scale
	preview_wrapper.add_child(_drag_preview)
	set_drag_preview(preview_wrapper)

	modulate.a = 0.4  # original card dims in place while its preview is dragged
	GameManager.highlight_available_seats(passenger_data)

	return {"ui_node": self, "logic_data": passenger_data}

# --- Drop forwarding for seated cards ---

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_seated:
		return false  # Card is in queue
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

func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		is_dragging = false
		_drag_preview = null
		GameManager.clear_seat_highlights()
		if not is_seated:
			modulate.a = 1.0
			if was_seated and current_seat_index >= 0:
				is_seated = true
				play_seated_animation(current_seat_index)
			else:
				set_standby()

# --- Data parsing ---
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
		# Lovey Dovey couples: lover_a → couple_1 sprite, lover_b → couple_2 sprite
		var pid_val = passenger_data.get("id")
		var pid: String = pid_val if pid_val != null else ""
		if pid.ends_with("_b") or pid.ends_with("lover_b"):
			anim_prefix = "couple_2"
		else:
			anim_prefix = "couple_1"
	elif passenger_data.get("is_balikbayan"):
		anim_prefix = "market_goer"
	elif passenger_data.get("is_heavy_load"):
		anim_prefix = "market_goer"
	elif passenger_data.get("is_parent_baby"):
		anim_prefix = "parent_baby"
	else:
		anim_prefix = "regular"

# --- State controllers ---

func set_standby():
	is_dragging = false
	is_seated = false
	was_seated = false  ## A standby card is a queue card, never "was seated"
	_play_anim(anim_sprite, anim_prefix + "_idle")

func play_seated_animation(grid_row: int):
	_strip_card_chrome()
	current_seat_index = grid_row 

	_seat_anim_id += 1
	var my_id := _seat_anim_id

	if grid_row == 0:
		# Upper/front bench → nakaharap sa driver → play _drop_front then settle in _idle
		var drop_anim := anim_prefix + "_drop_front"
		if anim_sprite.sprite_frames.has_animation(drop_anim):
			anim_sprite.play(drop_anim)
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return

		var blink_anim := anim_prefix + "_blink"
		if anim_prefix == "white_lady":
			blink_anim = "white_lady_lady_blink"

		_play_anim(anim_sprite, blink_anim)
		if anim_sprite.sprite_frames.has_animation(blink_anim):
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return 

		_play_anim(anim_sprite, anim_prefix + "_idle")
	else:
		# Lower/back bench → nakatalikod → play _drop_back then STOP on last frame
		var drop_anim := anim_prefix + "_drop_back"
		if anim_sprite.sprite_frames.has_animation(drop_anim):
			anim_sprite.play(drop_anim)
			await anim_sprite.animation_finished
			if _seat_anim_id != my_id:
				return 

## Pops the prepared Check/Cross emote animation above this card for a
## couple seconds, then fades it out. Called by GameManager after every
## seat/unseat validation pass -- replaces the old plain-text complaint
## notification for this passenger's happy/unhappy state.
func show_feedback(is_happy: bool) -> void:
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
	if _feedback_emote and is_instance_valid(_feedback_emote):
		_feedback_emote.queue_free()
		_feedback_emote = null

	_feedback_emote = OverheadEmoteScene.instantiate()
	add_child(_feedback_emote)
	_feedback_emote.modulate.a = 1.0
	# Sits above the passenger's head. Nudge this offset in the editor/here
	# if it doesn't line up with a particular sprite's frame size.
	_feedback_emote.position = Vector2(size.x / 2.0, -70)

	var emote_sprite: AnimatedSprite2D = _feedback_emote.get_node("AnimatedSprite2D")
	var anim_name := "Check" if is_happy else "Cross"
	emote_sprite.play(anim_name)
	# The sheet's animations are set to loop, which would make this blink
	# forever. Freeze it on its last frame the moment it gets there instead.
	emote_sprite.frame_changed.connect(_on_feedback_frame_changed.bind(emote_sprite))

	var emote_ref := _feedback_emote
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(2.8)
	_feedback_tween.tween_property(emote_ref, "modulate:a", 0.0, 0.4)
	_feedback_tween.tween_callback(func():
		if is_instance_valid(emote_ref):
			emote_ref.queue_free()
		if _feedback_emote == emote_ref:
			_feedback_emote = null
	)

func _on_feedback_frame_changed(sprite: AnimatedSprite2D) -> void:
	if not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return
	var anim := sprite.animation
	if not sprite.sprite_frames.has_animation(anim):
		return
	var last_frame := sprite.sprite_frames.get_frame_count(anim) - 1
	if sprite.frame == last_frame:
		sprite.pause()  # holds on this frame instead of looping back to 0

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
