extends HBoxContainer
## Scripts/UI/strike_counter.gd
## Tracks the "1-2-3 reclamations" loss condition. Dev 4 calls add_strike()
## whenever a rule violation or "1-2-3" penalty occurs; this is purely the
## visual counter, not the authority on when a strike happens.

signal max_strikes_reached

@export var max_strikes: int = 3
@export var filled_icon: Texture2D
@export var empty_icon: Texture2D

var _current_strikes: int = 0
var _icons: Array = []

func _ready() -> void:
	_build_icons()

func _build_icons() -> void:
	for child in get_children():
		child.queue_free()
	_icons.clear()
	for i in max_strikes:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = empty_icon
		add_child(icon)
		_icons.append(icon)

func add_strike() -> void:
	if _current_strikes >= max_strikes:
		return
	_icons[_current_strikes].texture = filled_icon
	_shake(_icons[_current_strikes])
	_current_strikes += 1
	if _current_strikes >= max_strikes:
		emit_signal("max_strikes_reached")

func reset() -> void:
	_current_strikes = 0
	for icon in _icons:
		icon.texture = empty_icon

func _shake(node: Control) -> void:
	var start_pos := node.position
	var tween := create_tween()
	tween.tween_property(node, "position:x", start_pos.x - 4, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 4, 0.05)
	tween.tween_property(node, "position:x", start_pos.x, 0.05)
