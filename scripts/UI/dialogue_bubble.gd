extends PanelContainer
## Scripts/UI/dialogue_bubble.gd
## ONE shared instance lives under HUD. Any clickable character (queue card
## or seated passenger, wired by Dev 2) calls set_text() on this same node —
## that's how "different character, same bubble" works.
##
## Confirmed against Dev 1's scripts/passenger.gd: monologue_text (String)
## matches exactly, no changes needed here.

signal shown
signal hidden

@onready var monologue_label: RichTextLabel = $Margin/MonologueLabel

const POPUP_DURATION := 0.15

## UI PASS (Dev 3): tail drawn in code (not a separate sprite) so it scales
## with the bubble's variable width/height. Colors match Resources/Theme
## jeepney_theme.tres's StyleBoxFlat_bubble fill/border — keep in sync if
## that stylebox changes.
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

	# Border first (slightly larger triangle), then fill on top, so only the
	# two outer slanted edges read as outlined — mimics the thick comic-panel
	# border in the reference art without needing a separate sprite.
	var border_left := left + (left - tip).normalized() * TAIL_BORDER_WIDTH
	var border_right := right + (right - tip).normalized() * TAIL_BORDER_WIDTH
	var border_tip := tip + (tip - Vector2(tip_x, base_y)).normalized() * TAIL_BORDER_WIDTH
	draw_colored_polygon(PackedVector2Array([border_left, border_right, border_tip]), TAIL_BORDER)
	draw_colored_polygon(PackedVector2Array([left, right, tip]), TAIL_FILL)

## Preferred entry point now that Dev 1's Passenger class is finalized.
func set_from_passenger(passenger: Passenger) -> void:
	set_text(passenger.monologue_text)

## Standalone entry point — also useful for system messages (e.g. driver lines).
func set_text(bbcode_text: String) -> void:
	monologue_label.text = bbcode_text
	await get_tree().process_frame  # let the container resize to new text height first
	queue_redraw()
	show_bubble()

## Optional: reposition the bubble above whichever node was clicked.
## Call this before set_text() if you want it to "follow" the speaker.
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
		emit_signal("hidden")
	)
