extends HBoxContainer
## Scripts/UI/strike_counter.gd
## Tracks the "1-2-3 reclamations" loss condition. Dev 4 calls add_strike()
## whenever a rule violation or "1-2-3" penalty occurs; this is purely the
## visual counter, not the authority on when a strike happens.
##
## UI PASS (Dev 3): strike pips are drawn in code (StyleBoxFlat circles)
## instead of loading icon textures, so this scene has no dependency on
## external art files. Swap _make_pip_style() for real icon textures once
## final art exists.

signal max_strikes_reached

const INK := Color(0.227, 0.153, 0.094, 1)
const COLOR_EMPTY := Color(0.910, 0.824, 0.651, 0.5)
const COLOR_FILLED := Color(0.776, 0.180, 0.165, 1)

@export var max_strikes: int = 3

var _current_strikes: int = 0
var _icons: Array = []

func _ready() -> void:
	_build_icons()

func _build_icons() -> void:
	for child in get_children():
		child.queue_free()
	_icons.clear()
	for i in max_strikes:
		var icon := PanelContainer.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.add_theme_stylebox_override("panel", _make_pip_style(COLOR_EMPTY))
		add_child(icon)
		_icons.append(icon)

func add_strike() -> void:
	if _current_strikes >= max_strikes:
		return
	_icons[_current_strikes].add_theme_stylebox_override("panel", _make_pip_style(COLOR_FILLED))
	_shake(_icons[_current_strikes])
	_current_strikes += 1
	if _current_strikes >= max_strikes:
		emit_signal("max_strikes_reached")

func reset() -> void:
	_current_strikes = 0
	for icon in _icons:
		icon.add_theme_stylebox_override("panel", _make_pip_style(COLOR_EMPTY))

func _make_pip_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = INK
	return style

func _shake(node: Control) -> void:
	var start_pos := node.position
	var tween := create_tween()
	tween.tween_property(node, "position:x", start_pos.x - 4, 0.05)
	tween.tween_property(node, "position:x", start_pos.x + 4, 0.05)
	tween.tween_property(node, "position:x", start_pos.x, 0.05)
