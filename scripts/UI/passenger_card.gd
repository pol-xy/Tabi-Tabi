class_name PassengerCard
extends Button

# Represents one passenger as a clickable card (queue strip or inspection).
# Button gives free click detection, no manual Area2D/input_event needed
# for UI-space cards.
#
# Field names below now match scripts/passenger.gd from Dev 1 exactly:
# id, passenger_name, seat_size_passenger, monologue_text, anger_meter_max,
# is_senior, is_pwd, is_pregnant, is_student, is_employee,
# is_companion, is_wet, is_sleepy, is_noisy, is_introvert, is_impatient,
# is_white_lady, alights_soon, destination_stop, companion_id.
# (is_badjao removed -- unused, ran into real-world stereotyping concerns.
#  is_asleep/is_loud were renamed to is_sleepy/is_noisy upstream; updated here.
#  alights_soon is the new finalized field for "near stop" -- destination_stop
#  still exists on Passenger but rule_validator.gd no longer reads it.)
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
#
# ANGER METER (Dev 4): is_impatient is an opt-in trait -- only passengers
# flagged with it (or White Lady, always, regardless of the flag) get a
# ticking AngerBar. Everyone else has none at all, not just a high max.
# The AngerBar child node is created in code (see _setup_anger_meter) rather
# than requiring a scene edit, so this works whether or not PassengerCard.tscn
# has been updated yet.

signal card_selected(passenger: Passenger)

const ANGER_BAR_SCENE := preload("res://Scenes/UI/AngerBar.tscn")

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
@onready var vbox: VBoxContainer = $VBox

var passenger_data: Passenger = null
var anger_bar: ProgressBar = null
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
	_setup_anger_meter(passenger)

# --- Anger meter (opt-in trait, see header note) ----------------------------

## White Lady is always treated as impatient, no matter the flag -- her
## urgency is part of the character, not something a designer toggles.
func _passenger_has_anger_meter(passenger: Passenger) -> bool:
	return passenger.is_impatient or passenger.is_white_lady

func _setup_anger_meter(passenger: Passenger) -> void:
	var has_meter := _passenger_has_anger_meter(passenger)

	if not has_meter:
		if anger_bar != null:
			anger_bar.pause()
			anger_bar.visible = false
		return

	if anger_bar == null:
		anger_bar = ANGER_BAR_SCENE.instantiate()
		vbox.add_child(anger_bar)
		anger_bar.depleted.connect(_on_anger_depleted)

	anger_bar.visible = true
	anger_bar.start_from_passenger(passenger)

# Reads the boolean flags on Passenger and turns them into a display list.
# Kept separate from _populate_traits so RuleValidator or other systems
# can call this same mapping if they ever need trait ids too.
func _derive_trait_ids(passenger: Passenger) -> Array[String]:
	var trait_ids: Array[String] = []
	if passenger.is_sleepy:
		trait_ids.append("sleepy")
	if passenger.is_introvert:
		trait_ids.append("introvert")
	if passenger.is_noisy:
		trait_ids.append("noisy")
	if passenger.is_wet:
		trait_ids.append("wet")
	if passenger.seat_size_passenger > 1:
		trait_ids.append("heavy_load")
	if passenger.alights_soon:
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

## Fired once when this passenger's anger meter hits zero (queue wait, or
## seated-and-unhappy -- AngerBar keeps running after reparenting into a
## seat, since Godot processing doesn't care who the parent is).
## Single entry point into GameManager's "1-2-3" penalty per the game
## manager's own doc comment. Handles cleanup for BOTH cases: still waiting
## in the queue, or already seated -- detach_passenger() is a safe no-op if
## this card isn't currently tracked in the queue's _cards array (i.e. it
## was already detached when seated, same as seat_1.gd does on drop).
func _on_anger_depleted() -> void:
	if passenger_data == null:
		return
	GameManager.trigger_penalty(passenger_data)

	var queue_panel = get_node_or_null("/root/Main_Jeepney/HUD/QueuePanel")
	if queue_panel:
		queue_panel.detach_passenger(passenger_data)

	queue_free()

func _on_pressed() -> void:
	# --- GRAYBOX TESTING FIX ---
	# Ensure the card has a fake ID before trying to talk!
	if passenger_data == null:
		passenger_data = Passenger.new()
		passenger_data.seat_size_passenger = 1
		passenger_data.monologue_text = "Hey! I am a graybox placeholder."
	# ---------------------------
	emit_signal("card_selected", passenger_data)
	
	var dialogue_bubble = get_node_or_null("/root/Main_Jeepney/HUD/DialogueBubble")
	if dialogue_bubble != null:
		dialogue_bubble.point_at(global_position, Vector2(0, -150))
		dialogue_bubble.set_from_passenger(passenger_data)

func _update_active_visual() -> void:
	scale = Vector2(1.1, 1.1) if is_active else Vector2.ONE
	modulate = Color.WHITE if is_active else Color(1, 1, 1, 0.7)
	
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview = self.duplicate()
	preview.modulate.a = 0.5 # Make the ghost transparent
	
	var preview_container = Control.new()
	preview_container.add_child(preview)
	preview.position = -self.size / 2 
	set_drag_preview(preview_container)
	
	return {
		"ui_node": self,
		"logic_data": passenger_data 
	}
	
