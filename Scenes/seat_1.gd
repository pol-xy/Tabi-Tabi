extends ColorRect

@export var grid_row: int 
@export var grid_col: int 
@onready var jeepney_grid = get_tree().root.get_node("Main_Jeepney/JeepneyGridManager")

const GLOW_COLOR := Color(1.0, 0.92, 0.3, 0.28)
const GLOW_COLOR_PEAK := Color(1.0, 0.92, 0.3, 0.6)
const HOVER_COLOR := Color(0.0, 0.658, 0.089, 0.65)

var _is_highlighted: bool = false
var _glow_tween: Tween = null

func _ready():
	# Hides the flat placeholder rectangle
	color = Color(1, 1, 1, 0)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## Called by GameManager the moment a card starts being dragged, for every
## seat that could legally take that passenger.
func show_available_highlight() -> void:
	_is_highlighted = true
	_start_pulse()

## Called by GameManager when the drag ends (drop or cancel).
func clear_highlight() -> void:
	_is_highlighted = false
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	color = Color(1, 1, 1, 0)

func _start_pulse() -> void:
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	color = GLOW_COLOR
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(self, "color", GLOW_COLOR_PEAK, 0.45)
	_glow_tween.tween_property(self, "color", GLOW_COLOR, 0.45)

func _on_mouse_entered() -> void:
	if not _is_highlighted:
		return
	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	color = HOVER_COLOR

func _on_mouse_exited() -> void:
	if _is_highlighted:
		_start_pulse()

# Check if the object hovering over this seat is a valid passenger
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if GameManager._stage_finishing:
		return false
	if typeof(data) == TYPE_DICTIONARY and data.has("logic_data") and data.has("ui_node"):
		var passenger = data["logic_data"]
		# Empty seat is dropable if dimensions match
		if jeepney_grid.can_place_passenger(passenger, grid_row, grid_col):
			return true
		# Occupied seat is dropable for swapping/kicking
		var occupant = jeepney_grid.seats[grid_row][grid_col]
		if occupant != null and occupant != passenger:
			return true
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if GameManager._stage_finishing:
		return
	var passenger_node = data["ui_node"]
	if not is_instance_valid(passenger_node):
		return
	var passenger = data["logic_data"]

	var target_occupant = jeepney_grid.seats[grid_row][grid_col]
	
	if target_occupant == passenger:
		# Dropped back on the SAME seat — restore the correct seated visual
		passenger_node.is_seated = true
		passenger_node.modulate.a = 1.0
		passenger_node.play_seated_animation(grid_row)
		return

	if target_occupant == null:
		# Standard drop logic
		var old_parent = passenger_node.get_parent()
		if old_parent:
			old_parent.remove_child(passenger_node)
		add_child(passenger_node)

		# The card only ever dimmed itself during the drag (a disposable preview
		# handled the on-screen movement) -- restore full opacity now that it's
		# actually landing somewhere, and mark it seated so it doesn't reset
		# itself back to standby.
		passenger_node.is_seated = true
		passenger_node.modulate.a = 1.0
		passenger_node.z_index = 10

		# Now that this seat is its parent, a local (not global) offset centers it.
		passenger_node.position = (self.size - passenger_node.size) / 2.0

		passenger_node.play_seated_animation(grid_row)

		# Tell backend to occupy the grid slot
		jeepney_grid.place_passenger(passenger, grid_row, grid_col)

		# Tell Dev 4's GameManager so it can run validation, award fare, and
		# check the stage quota. (This also detaches the card from the queue's
		# own bookkeeping, since it's no longer waiting in line.)
		GameManager.on_passenger_seated(passenger)

		print("Success! Passenger seated at Row: ", grid_row, " Col: ", grid_col)
	else:
		# Seat is occupied -> Perform Swapping or Kicking!
		var ui_node_b: PassengerCard = null
		for child in get_children():
			if child is PassengerCard and child.passenger_data == target_occupant:
				ui_node_b = child
				break
				
		if ui_node_b == null:
			return # Fallback safety check
			
		if passenger_node.was_seated:
			# --- Case A: Seated-to-Seated Swap ---
			var seat_a = passenger_node.get_parent()
			if seat_a and seat_a.has_method("_drop_data"):
				var row_a = seat_a.grid_row
				var col_a = seat_a.grid_col
				
				# Remove both nodes from their old parents
				seat_a.remove_child(passenger_node)
				self.remove_child(ui_node_b)
				
				# Swap their parent containers
				self.add_child(passenger_node)
				seat_a.add_child(ui_node_b)
				
				# Center visual offsets
				passenger_node.position = (self.size - passenger_node.size) / 2.0
				ui_node_b.position = (seat_a.size - ui_node_b.size) / 2.0
				
				# IMPORTANT: Mark both as seated BEFORE NOTIFICATION_DRAG_END fires,
				# otherwise _notification sees is_seated=false and calls set_standby()
				# which would overwrite the seated animation with _idle.
				passenger_node.is_seated = true
				ui_node_b.is_seated = true
				passenger_node.modulate.a = 1.0
				ui_node_b.modulate.a = 1.0
				
				# Clear logical slots first to avoid validation conflicts during placement
				jeepney_grid.seats[row_a][col_a] = null
				jeepney_grid.seats[grid_row][grid_col] = null
				
				# Set new logical coordinates
				jeepney_grid.place_passenger(passenger, grid_row, grid_col)
				jeepney_grid.place_passenger(target_occupant, row_a, col_a)
				
				# Animate both passengers into their new seats
				passenger_node.play_seated_animation(grid_row)
				ui_node_b.play_seated_animation(row_a)
				
				# Notify GameManager (updates status and checks rules)
				GameManager.on_passenger_seated(passenger)
				GameManager.on_passenger_seated(target_occupant)
				print("[seat_1] Swapped seats: (", row_a, ",", col_a, ") <-> (", grid_row, ",", grid_col, ")")
		else:
			# --- Case B: Queue-to-Occupied Swap (Kicking occupant to queue) ---
			var hud = GameManager.hud
			if hud and hud.queue_panel:
				var queue_panel = hud.queue_panel
				
				# 1. Kick target occupant B back to queue
				GameManager.unseat_passenger(target_occupant)
				self.remove_child(ui_node_b)
				queue_panel.card_row.add_child(ui_node_b)
				ui_node_b.set_standby()
				ui_node_b.restore_card_chrome()
				queue_panel._cards.append(ui_node_b)
				queue_panel._set_active(0)
				
				# 2. Place incoming passenger A in this seat
				var old_parent = passenger_node.get_parent()
				if old_parent:
					old_parent.remove_child(passenger_node)
				self.add_child(passenger_node)
				
				passenger_node.is_seated = true
				passenger_node.modulate.a = 1.0
				passenger_node.z_index = 10
				passenger_node.position = (self.size - passenger_node.size) / 2.0
				passenger_node.play_seated_animation(grid_row)
				
				jeepney_grid.place_passenger(passenger, grid_row, grid_col)
				GameManager.on_passenger_seated(passenger)
				print("Kicked occupant to queue, seated incoming passenger at: ", grid_row, ", ", grid_col)
