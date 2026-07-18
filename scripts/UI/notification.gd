extends VBoxContainer
## Scripts/UI/notification.gd

const DISPLAY_SECONDS := 1.8
const FADE_SECONDS := 0.25
const MAX_VISIBLE := 4  

@export var toast_scene: PackedScene 

var _active_toasts: Array[Control] = []  ## Oldest-first, currently on screen
var _active_messages: Dictionary = {}    ## Message text -> Control, for dedupe

func push(message: String, type: String = "info") -> void:
	if _active_messages.has(message):
		return

	while _active_toasts.size() >= MAX_VISIBLE:
		var oldest: Control = _active_toasts.pop_front()
		if is_instance_valid(oldest):
			_active_messages.erase(oldest.get_meta("message", ""))
			oldest.queue_free()

	var toast: Control = _build_toast(message, type)
	toast.set_meta("message", message)
	add_child(toast)
	_active_toasts.append(toast)
	_active_messages[message] = toast

	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(DISPLAY_SECONDS)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_remove_toast.bind(toast))

func _remove_toast(toast: Control) -> void:
	_active_toasts.erase(toast)
	if is_instance_valid(toast):
		_active_messages.erase(toast.get_meta("message", ""))
		toast.queue_free()

func _build_toast(message: String, type: String) -> Control:
	var toast: Control
	if toast_scene:
		toast = toast_scene.instantiate()
		if toast.has_method("set_text"):
			toast.set_text(message)
	else:
		var label := Label.new()
		label.text = message
		label.add_theme_color_override("font_color", Color(0.961, 0.914, 0.784, 1))
		label.add_theme_font_size_override("font_size", 14)

		var pill := PanelContainer.new()
		var box := StyleBoxFlat.new()
		box.bg_color = _color_for_type(type)
		box.set_corner_radius_all(8)
		box.set_border_width_all(2)
		box.border_color = Color(0.227, 0.153, 0.094, 1)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		pill.add_theme_stylebox_override("panel", box)
		pill.add_child(label)
		toast = pill
	return toast

func _color_for_type(type: String) -> Color:
	match type:
		"success": return Color(0.165, 0.549, 0.278, 1)  # satisfied green
		"error": return Color(0.776, 0.180, 0.165, 1)     # jeepney red
		_: return Color(0.227, 0.153, 0.094, 1)           # ink/neutral
