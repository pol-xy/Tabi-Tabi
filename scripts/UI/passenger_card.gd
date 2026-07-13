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

signal card_selected(passenger: Passenger)

const TRAIT_ICON_PATHS := {
	"sleepy": "res://Assets/Icons/status/sleepy.png",
	"introvert": "res://Assets/Icons/status/introvert.png",
	"noisy": "res://Assets/Icons/status/noisy.png",
	"wet": "res://Assets/Icons/status/wet.png",
	"heavy_load": "res://Assets/Icons/status/heavy_load.png",
	"near_stop": "res://Assets/Icons/status/near_stop.png",
}
const MAX_VISIBLE_TRAIT_ICONS := 3

@onready var portrait: TextureRect = $VBox/Portrait
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
		var trait_id: String = trait_ids[i]
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if TRAIT_ICON_PATHS.has(trait_id) and ResourceLoader.exists(TRAIT_ICON_PATHS[trait_id]):
			icon.texture = load(TRAIT_ICON_PATHS[trait_id])
		trait_row.add_child(icon)
	if trait_ids.size() > MAX_VISIBLE_TRAIT_ICONS:
		var overflow := Label.new()
		overflow.text = "+%d" % (trait_ids.size() - MAX_VISIBLE_TRAIT_ICONS)
		overflow.add_theme_font_size_override("font_size", 10)
		trait_row.add_child(overflow)

func _on_pressed() -> void:
	emit_signal("card_selected", passenger_data)

func _update_active_visual() -> void:
	scale = Vector2(1.1, 1.1) if is_active else Vector2.ONE
	modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.7)
