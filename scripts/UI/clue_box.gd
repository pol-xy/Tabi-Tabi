class_name ClueBox
extends PanelContainer
# scripts/UI/clue_box.gd
#
# Cardboard "fare log" clue box — matches the reference sketch (Name / role
# header, underline, checklist of clue lines). No portrait, no close button:
# just three swappable fields that update to whichever Passenger is being
# dragged or inspected.
#
# ClueBox.tscn sets its own local StyleBoxFlat panel/border color (a richer
# wood tone) instead of inheriting jeepney_theme.tres's pale cardboard, to
# match the wood-sign look in the reference art -- same ink border color
# as the rest of the HUD, just a different fill.
#
# Public API:
#   show_for_passenger(passenger: Passenger) -> void   # call on drag start / click
#   clear() -> void                                    # back to placeholder text
#   set_clue_satisfied(index: int, satisfied: bool) -> void  # optional strikethrough hook
#
# Added to the "clue_box" group so any script can reach it without a hard
# path dependency, e.g. from passenger_card.gd's _get_drag_data:
#   var clue_box = get_tree().get_first_node_in_group("clue_box")
#   if clue_box:
#       clue_box.show_for_passenger(passenger_data)

const DEFAULT_NAME := "Name"
const DEFAULT_ROLE := "role"
const DEFAULT_CLUES: Array[String] = ["clue", "clue"]
const MAX_CLUE_LINES := 3

@onready var name_label: Label = $Margin/VBox/HeaderRow/NameLabel
@onready var role_label: Label = $Margin/VBox/HeaderRow/RoleLabel
@onready var clue_list: VBoxContainer = $Margin/VBox/ClueList

var _current_passenger: Passenger = null

func _ready() -> void:
	add_to_group("clue_box")
	clear()

## Call whenever a passenger is picked up (drag start) or clicked (inspect).
func show_for_passenger(passenger: Passenger) -> void:
	if passenger == null:
		clear()
		return
	_current_passenger = passenger
	name_label.text = passenger.passenger_name if passenger.passenger_name != "" else DEFAULT_NAME
	role_label.text = _derive_role_label(passenger)
	_populate_clues(_derive_clue_lines(passenger))

## Resets to placeholder text -- call on drag end / deselect if you want the
## box to go blank again, otherwise it's fine to just leave the last shown
## passenger up until the next drag.
func clear() -> void:
	_current_passenger = null
	name_label.text = DEFAULT_NAME
	role_label.text = DEFAULT_ROLE
	_populate_clues(DEFAULT_CLUES)

## Optional: strike through a clue line once its rule is satisfied, for the
## "Clue Manifest" checklist behavior from the concept doc. index matches
## the order returned by _derive_clue_lines().
func set_clue_satisfied(index: int, satisfied: bool) -> void:
	if index < 0 or index >= clue_list.get_child_count():
		return
	var row := clue_list.get_child(index)
	var label: Label = row.get_node("ClueLabel")
	var check: Panel = row.get_node("CheckSquare")
	label.text = ("[s]%s[/s]" % label.text.replace("[s]", "").replace("[/s]", "")) if satisfied else label.text.replace("[s]", "").replace("[/s]", "")
	check.self_modulate = Color(0.31, 0.68, 0.33, 1) if satisfied else Color(1, 1, 1, 1)

# --- derivation -------------------------------------------------------------
# Passenger (scripts/passenger.gd) has no dedicated "role" or "clue list"
# field -- only category-ish booleans and one free-text monologue_text. This
# maps those to display strings the way passenger_card.gd's trait derivation
# does, so nothing here contradicts Dev 1's real Resource fields.

func _derive_role_label(passenger: Passenger) -> String:
	if passenger.is_pwd:
		return "PWD"
	if passenger.is_pregnant:
		return "Pregnant"
	if passenger.is_senior:
		return "Senior"
	if passenger.is_student:
		return "Student"
	if passenger.is_employee:
		return "Employee"
	if passenger.is_badjao:
		return "Badjao"
	return "Regular"

# FLAG FOR THE TEAM: there's no dedicated Array[String] of short clue lines
# on Passenger yet -- only monologue_text (one paragraph). Until Dev 1 adds
# something like requirement_clues: Array[String], this splits monologue_text
# on sentence punctuation as a stand-in. Swap the fallback branch below the
# moment that field exists.
func _derive_clue_lines(passenger: Passenger) -> Array[String]:
	if "requirement_clues" in passenger and passenger.requirement_clues is Array and not passenger.requirement_clues.is_empty():
		var typed: Array[String] = []
		typed.assign(passenger.requirement_clues)
		return typed
	var lines: Array[String] = []
	for chunk in passenger.monologue_text.split(".", false):
		var trimmed := chunk.strip_edges()
		if trimmed != "":
			lines.append(trimmed)
		if lines.size() >= MAX_CLUE_LINES:
			break
	if lines.is_empty():
		lines.append(passenger.monologue_text if passenger.monologue_text != "" else DEFAULT_CLUES[0])
	return lines

func _populate_clues(lines: Array[String]) -> void:
	for child in clue_list.get_children():
		child.queue_free()
	for line in lines:
		clue_list.add_child(_make_clue_row(line))

func _make_clue_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var check := Panel.new()
	check.name = "CheckSquare"
	check.custom_minimum_size = Vector2(14, 14)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var check_style := StyleBoxFlat.new()
	check_style.bg_color = Color(1, 1, 1, 0.5)
	check_style.border_color = Color(0.227, 0.153, 0.094, 1)
	check_style.set_border_width_all(2)
	check_style.set_corner_radius_all(2)  # square, matching the reference art
	check.add_theme_stylebox_override("panel", check_style)
	row.add_child(check)

	var label := Label.new()
	label.name = "ClueLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	return row
