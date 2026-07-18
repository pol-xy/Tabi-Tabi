extends Area2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# --- Drag variables ---

var dragging: bool = false

var current_seat: Area2D = null
var hover_seat: Area2D = null

var drag_start_position: Vector2
var mouse_offset: Vector2 = Vector2.ZERO

var facing_right := true

# --- Ready ---

func _ready():
	input_pickable = true
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	randomize()
	play_idle_animation()

# --- Mouse input ---

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			start_drag()
		else:
			stop_drag()

# --- Drag start ---

func start_drag():
	dragging = true
	mouse_offset = global_position - get_global_mouse_position()
	drag_start_position = global_position
	
	if current_seat != null:
		current_seat.remove_passenger()
		current_seat = null
		
	play_drag_animation()

# --- Drag end ---

func stop_drag():
	dragging = false
	
	if hover_seat != null and hover_seat.can_accept_passenger():
		hover_seat.assign_passenger(self)
		current_seat = hover_seat
		global_position = hover_seat.get_snap_position()
		play_drop_animation()
		return
		
	global_position = drag_start_position
	play_drop_animation()

# --- Process ---

func _process(delta):
	if !dragging:
		return
	var mouse = get_global_mouse_position()
	if mouse.x > global_position.x:
		facing_right = true
	elif mouse.x < global_position.x:
		facing_right = false
	global_position = mouse + mouse_offset

# --- Seat detection ---

func _on_area_entered(area):
	if area.is_in_group("Seats"):
		hover_seat = area

func _on_area_exited(area):
	if area == hover_seat:
		hover_seat = null

# --- Animations ---

func play_drag_animation():
	if facing_right:
		if animated_sprite.sprite_frames.has_animation("drag right"):
			animated_sprite.play("drag right")
		elif animated_sprite.sprite_frames.has_animation("drag up"):
			animated_sprite.play("drag up")
	else:
		if animated_sprite.sprite_frames.has_animation("drag left"):
			animated_sprite.play("drag left")
		elif animated_sprite.sprite_frames.has_animation("drag up"):
			animated_sprite.play("drag up")

func play_drop_animation():
	if current_seat == null:
		if animated_sprite.sprite_frames.has_animation("drop front"):
			animated_sprite.play("drop front")
			await animated_sprite.animation_finished
		play_idle_animation()
		return
	match current_seat.name:
		"Seat01", "Seat02", "Seat03", "Seat04", "Seat05":
			if animated_sprite.sprite_frames.has_animation("drop back"):
				animated_sprite.play("drop back")
		"Seat06", "Seat07", "Seat08", "Seat09", "Seat10":
			if animated_sprite.sprite_frames.has_animation("drop front"):
				animated_sprite.play("drop front")
			if animated_sprite.sprite_frames.has_animation("drop front"):
				animated_sprite.play("drop front")
				
	await animated_sprite.animation_finished
	play_idle_animation()

func play_idle_animation():
	if facing_right:
		if animated_sprite.sprite_frames.has_animation("idle right"):
			animated_sprite.play("idle right")
			return

	if !facing_right:
		if animated_sprite.sprite_frames.has_animation("idle left"):
			animated_sprite.play("idle left")
			return

	if animated_sprite.sprite_frames.has_animation("idle"):
		animated_sprite.play("idle")

# --- Optional animations ---

func walk_left():
	if animated_sprite.sprite_frames.has_animation("walk left"):
		animated_sprite.play("walk left")

func walk_right():
	if animated_sprite.sprite_frames.has_animation("walk right"):
		animated_sprite.play("walk right")

func blink():
	if animated_sprite.sprite_frames.has_animation("blink"):
		animated_sprite.play("blink")

		await animated_sprite.animation_finished
		play_idle_animation()

func look_around():
	if animated_sprite.sprite_frames.has_animation("look around"):
		animated_sprite.play("look around")
		await animated_sprite.animation_finished
		play_idle_animation()

func play_random_idle():
	if dragging:
		return
		
	var choices: Array[String] = []

	if animated_sprite.sprite_frames.has_animation("idle"):
		choices.append("idle")

	if animated_sprite.sprite_frames.has_animation("blink"):
		choices.append("blink")

	if animated_sprite.sprite_frames.has_animation("look around"):
		choices.append("look around")

	if choices.is_empty():
		return

	var anim = choices.pick_random()

	animated_sprite.play(anim)

	if anim != "idle":
		await animated_sprite.animation_finished
		play_idle_animation()
