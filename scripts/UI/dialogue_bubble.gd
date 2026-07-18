extends PanelContainer
## Scripts/UI/dialogue_bubble.gd

signal shown
signal bubble_hidden

@onready var monologue_label: RichTextLabel = $Margin/MonologueLabel

const POPUP_DURATION := 0.15
const TAIL_FILL := Color(0.961, 0.914, 0.784, 1)
const TAIL_BORDER := Color(0.227, 0.153, 0.094, 1)
const TAIL_WIDTH := 26.0
const TAIL_HEIGHT := 16.0
const TAIL_BORDER_WIDTH := 4.0

func _ready() -> void:
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	visible = false

func _draw() -> void:
	var w := size.x
	var h := size.y
	var tip_x := w * 0.5
	var base_y := h - 2.0  # slight overlap into the panel's rounded bottom edge
	var left := Vector2(tip_x - TAIL_WIDTH * 0.5, base_y)
	var right := Vector2(tip_x + TAIL_WIDTH * 0.5, base_y)
	var tip := Vector2(tip_x, h + TAIL_HEIGHT)
	var border_left := left + (left - tip).normalized() * TAIL_BORDER_WIDTH
	var border_right := right + (right - tip).normalized() * TAIL_BORDER_WIDTH
	var border_tip := tip + (tip - Vector2(tip_x, base_y)).normalized() * TAIL_BORDER_WIDTH
	draw_colored_polygon(PackedVector2Array([border_left, border_right, border_tip]), TAIL_BORDER)
	draw_colored_polygon(PackedVector2Array([left, right, tip]), TAIL_FILL)

func set_from_passenger(passenger: Passenger) -> void:
	set_text(passenger.monologue_text)

func set_text(bbcode_text: String) -> void:
	monologue_label.text = bbcode_text
	await get_tree().process_frame  # let the container resize to new text height first
	queue_redraw()
	show_bubble()

	await get_tree().create_timer(_read_duration_for(bbcode_text)).timeout
	hide_bubble()

## Roughly how long an average reader needs to read this text, with a floor
## so short lines don't vanish instantly and no real ceiling for long ones.
func _read_duration_for(bbcode_text: String) -> float:
	var plain_len := bbcode_text.length()
	const SECONDS_PER_CHAR := 0.1  # ~ a comfortable reading pace
	const MIN_SECONDS := 5
	return max(MIN_SECONDS, plain_len * SECONDS_PER_CHAR)

func point_at(world_or_ui_position: Vector2, offset: Vector2 = Vector2(0, -70)) -> void:
	global_position = world_or_ui_position + offset

func show_bubble() -> void:
	visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, POPUP_DURATION)
	tween.tween_property(self, "scale", Vector2.ONE, POPUP_DURATION)
	emit_signal("shown")

func hide_bubble() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, POPUP_DURATION)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), POPUP_DURATION)
	tween.chain().tween_callback(func():
		visible = false
		emit_signal("bubble_hidden")
	)
