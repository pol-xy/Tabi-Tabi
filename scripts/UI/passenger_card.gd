class_name PassengerCard
extends Button
# Represents one passenger as a clickable card (queue strip or inspection).
# Button gives free click detection, no manual Area2D/input_event needed
# for UI-space cards.
#
# Field names below now match scripts/passenger.gd from Dev 1 exactly:
# id, passenger_name, seat_size_passenger, monologue_text, anger_meter_max,
# is_senior, is_pwd, is_pregnant, is_student, is_employee, is_badjao,
# is_companion, is_wet, is_asleep, is_loud, is_introvert, destination_stop,
# companion_id.
#
# NOTE: Passenger has no direct "traits" array -- the trait icons shown on
# the card are derived below from the boolean flags. "sweaty" was on the
# original trait list from the concept doc but has no matching flag on
# Passenger yet -- flag this to Dev 1 if it's still wanted.
#
# UI PASS (Dev 3): trait badges are drawn in code (colored circle + short
# label) instead of loading image icons, so this scene has zero dependency
# on external art files. Swap _make_trait_badge() for real icon textures
# once final art exists -- everything else (derivation, layout) stays the same.

signal card_selected(passenger: Passenger)

const TRAIT_BADGES := {
	"sleepy": {"text": "Z", "color": Color(0.55, 0.45, 0.75)},
	"introvert": {"text": "I", "color": Color(0.35, 0.55, 0.65)},
	"noisy": {"text": "!", "color": Color(0.85, 0.55, 0.15)},
	"wet": {"text": "~", "color": Color(0.23, 0.49, 0.65)},
	"heavy_load": {"text": "B", "color": Color(0.71, 0.47, 0.18)},
	"near_stop": {"text": "»", "color": Color(0.78, 0.18, 0.16)},
}
const MAX_VISIBLE_TRAIT_ICONS := 3

@onready var portrait: Control = $VBox/Portrait
@onready var name_label: Label = $VBox/NameLabel
@onready var trait_row: HBoxContainer = $VBox/TraitRow

var passenger_data: Passenger = null
var is_active: bool = false:
	set(v):
		is_active = v
		_update_active_visual()

func _ready() -> void:
	pressed.connect(_on_pressed)

# Populates the card from a real Passenger resource.
func setup(passenger: Passenger) -> void:
	passenger_data = passenger
	name_label.text = passenger.passenger_name if passenger.passenger_name != "" else "???"
	_populate_traits(_derive_trait_ids(passenger))

# Reads the boolean flags on Passenger and turns them into a display list.
# Kept separate from _populate_traits so RuleValidator or other systems
# can call this same mapping if they ever need trait ids too.
func _derive_trait_ids(passenger: Passenger) -> Array[String]:
	var trait_ids: Array[String] = []
	if passenger.is_asleep:
		trait_ids.append("sleepy")
	if passenger.is_introvert:
		trait_ids.append("introvert")
	if passenger.is_loud:
		trait_ids.append("noisy")
	if passenger.is_wet:
		trait_ids.append("wet")
	if passenger.seat_size_passenger > 1:
		trait_ids.append("heavy_load")
	if passenger.destination_stop == 1:
		trait_ids.append("near_stop")
	return trait_ids

func _populate_traits(trait_ids: Array[String]) -> void:
	for child in trait_row.get_children():
		child.queue_free()
	for i in min(trait_ids.size(), MAX_VISIBLE_TRAIT_ICONS):
		trait_row.add_child(_make_trait_badge(trait_ids[i]))
	if trait_ids.size() > MAX_VISIBLE_TRAIT_ICONS:
		var overflow := Label.new()
		overflow.text = "+%d" % (trait_ids.size() - MAX_VISIBLE_TRAIT_ICONS)
		overflow.add_theme_font_size_override("font_size", 10)
		trait_row.add_child(overflow)

## Builds a small colored circle badge with a short label -- placeholder
## stand-in for a real trait icon sprite. No external files required.
func _make_trait_badge(trait_id: String) -> Control:
	var info: Dictionary = TRAIT_BADGES.get(trait_id, {"text": "?", "color": Color(0.5, 0.5, 0.5)})
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(16, 16)
	var box := StyleBoxFlat.new()
	box.bg_color = info["color"]
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.border_color = Color(0.227, 0.153, 0.094, 1)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = info["text"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 1))
	badge.add_child(label)
	return badge

func _on_pressed() -> void:
	emit_signal("card_selected", passenger_data)

func _update_active_visual() -> void:
	scale = Vector2(1.1, 1.1) if is_active else Vector2.ONE
	modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.7)
