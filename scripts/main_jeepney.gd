extends Control
## scripts/main_jeepney.gd

@onready var hud := $HUD
@onready var grid_manager := $JeepneyGridManager
@onready var _grid_container := get_node_or_null("Jeepney_BG/GridContainer")
@onready var _bg_sprite := get_node_or_null("Jeepney_BG/BG_Sprite")
@onready var _jeep_exterior := get_node_or_null("Jeepney_BG/JeepExterior")

# --- Keyboard selection & navigation ---
var selected_row: int = 0
var selected_col: int = 0
var lifted_card: PassengerCard = null
var lifted_seat: Node = null
var selector_cursor: Panel = null

func _ready() -> void:
	GameManager.register_hud(hud)
	GameManager.register_grid(grid_manager)
	GameManager.register_seat_nodes(_collect_seat_nodes())
	GameManager.register_background(_bg_sprite)
	GameManager.register_jeep_exterior(_jeep_exterior)

	if not grid_manager.dimensions_changed.is_connected(_on_grid_dimensions_changed):
		grid_manager.dimensions_changed.connect(_on_grid_dimensions_changed)

	if not GameManager.campaign_complete.is_connected(_on_campaign_complete):
		GameManager.campaign_complete.connect(_on_campaign_complete)

	_create_selector_cursor()
	GameManager.start_campaign()

func _on_campaign_complete() -> void:
	get_tree().change_scene_to_file("res://Scenes/Main/EndCredits.tscn")

func _on_grid_dimensions_changed(_rows: int, cols: int) -> void:
	selected_row = 0
	selected_col = 0
	
	# Deselect any lifted card during level changes
	if lifted_card:
		if is_instance_valid(lifted_card) and lifted_seat:
			lifted_card.position = (lifted_seat.size - lifted_card.size) / 2.0
			lifted_card.modulate.a = 1.0
		lifted_card = null
		lifted_seat = null

	var seats = _collect_seat_nodes()
	
	const CABIN_CENTER_X := 210.0
	const SEAT_W         := 64.0   # custom_minimum_size.x of every seat node

	var step_x: float = 0.0
	var row_y_offsets = [0.0, 96.0]

	if cols == 4:
		step_x = 86.0
	else:
		step_x = 74.0

	var total_row_w := (cols - 1) * step_x + SEAT_W
	var start_x     := CABIN_CENTER_X - total_row_w / 2.0

	for seat in seats:
		if seat == null:
			continue
		var r = seat.grid_row
		var c = seat.grid_col
		
		var local_x = start_x + (c * step_x)
		var local_y = row_y_offsets[r]
		seat.position = Vector2(local_x, local_y)

	_update_selector_position()

func _collect_seat_nodes() -> Array:
	var seats: Array = []
	if _grid_container:
		for child in _grid_container.get_children():
			# Ignore our visual selector cursor node
			if child.name != "KeyboardSelectorCursor":
				seats.append(child)
	return seats

# --- Keyboard Seating Methods ---

func _create_selector_cursor() -> void:
	selector_cursor = Panel.new()
	selector_cursor.name = "KeyboardSelectorCursor"
	selector_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE # let clicks pass through to cards
	
	var style = StyleBoxFlat.new()
	style.draw_center = false
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.9, 0.1, 0.8) # Vibrant yellow
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	
	selector_cursor.add_theme_stylebox_override("panel", style)
	if _grid_container:
		_grid_container.add_child(selector_cursor)
	_update_selector_position()

func _update_selector_position() -> void:
	if selector_cursor == null:
		return
	var seat = _get_seat_node(selected_row, selected_col)
	if seat:
		selector_cursor.position = seat.position
		selector_cursor.size = seat.size
		selector_cursor.show()
	else:
		selector_cursor.hide()

func _get_seat_node(row: int, col: int) -> Node:
	for seat in GameManager._seat_nodes:
		if seat and seat.grid_row == row and seat.grid_col == col:
			return seat
	return null

func _get_passenger_card_at_seat(seat_node: Node) -> PassengerCard:
	if seat_node == null:
		return null
	for child in seat_node.get_children():
		if child is PassengerCard:
			return child
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_stage_active():
		return
	if GameManager._stage_finishing:
		return

	var moved = false
	if event.is_action_pressed("ui_left") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		selected_col = max(0, selected_col - 1)
		moved = true
	elif event.is_action_pressed("ui_right") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		selected_col = min(grid_manager.col_count - 1, selected_col + 1)
		moved = true
	elif event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		selected_row = max(0, selected_row - 1)
		moved = true
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		selected_row = min(grid_manager.row_count - 1, selected_row + 1)
		moved = true
	elif event.is_action_pressed("ui_accept"):
		_handle_keyboard_action()
		get_viewport().set_input_as_handled()

	if moved:
		_update_selector_position()
		get_viewport().set_input_as_handled()

func _handle_keyboard_action() -> void:
	var current_seat = _get_seat_node(selected_row, selected_col)
	if current_seat == null:
		return
		
	var current_card = _get_passenger_card_at_seat(current_seat)
	
	if lifted_card == null:
		# --- Pick up passenger ---
		if current_card != null:
			lifted_card = current_card
			lifted_seat = current_seat
			lifted_card.position.y -= 10
			lifted_card.modulate.a = 0.7
			GameManager.play_sfx("drag_passenger")
			print("[Keyboard] Picked up: ", lifted_card.passenger_data.id)
	else:
		# --- Drop passenger ---
		if current_seat == lifted_seat:
			# Deselect / Cancel movement
			lifted_card.position = (lifted_seat.size - lifted_card.size) / 2.0
			lifted_card.modulate.a = 1.0
			lifted_card = null
			lifted_seat = null
			GameManager.play_sfx("click_select")
			print("[Keyboard] Deselected")
		else:
			var passenger = lifted_card.passenger_data
			var target_occupant = grid_manager.seats[selected_row][selected_col]
			var row_a = lifted_seat.grid_row
			var col_a = lifted_seat.grid_col
			
			if target_occupant == null:
				# --- Move to empty seat ---
				grid_manager.seats[row_a][col_a] = null
				grid_manager.place_passenger(passenger, selected_row, selected_col)
				
				lifted_seat.remove_child(lifted_card)
				current_seat.add_child(lifted_card)
				
				lifted_card.is_seated = true
				lifted_card.modulate.a = 1.0
				lifted_card.position = (current_seat.size - lifted_card.size) / 2.0
				lifted_card.play_seated_animation(selected_row)
				
				GameManager.on_passenger_seated(passenger)
				GameManager.play_sfx("click_select")
				print("[Keyboard] Moved to empty seat: (", selected_row, ", ", selected_col, ")")
			else:
				# --- Swap with occupied seat ---
				var ui_node_b = current_card
				if ui_node_b != null:
					lifted_seat.remove_child(lifted_card)
					current_seat.remove_child(ui_node_b)
					
					current_seat.add_child(lifted_card)
					lifted_seat.add_child(ui_node_b)
					
					lifted_card.is_seated = true
					ui_node_b.is_seated = true
					lifted_card.modulate.a = 1.0
					ui_node_b.modulate.a = 1.0
					
					lifted_card.position = (current_seat.size - lifted_card.size) / 2.0
					ui_node_b.position = (lifted_seat.size - ui_node_b.size) / 2.0
					
					grid_manager.seats[row_a][col_a] = null
					grid_manager.seats[selected_row][selected_col] = null
					grid_manager.place_passenger(passenger, selected_row, selected_col)
					grid_manager.place_passenger(target_occupant, row_a, col_a)
					
					lifted_card.play_seated_animation(selected_row)
					ui_node_b.play_seated_animation(row_a)
					
					GameManager.on_passenger_seated(passenger)
					GameManager.on_passenger_seated(target_occupant)
					GameManager.play_sfx("click_select")
					print("[Keyboard] Swapped: (", row_a, ",", col_a, ") <-> (", selected_row, ",", selected_col, ")")
			
			lifted_card = null
			lifted_seat = null
