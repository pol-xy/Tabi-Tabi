extends CanvasLayer
## Scripts/UI/hud.gd
## QueuePanel.passenger_focused      -> DialogueBubble.set_from_passenger
## StrikeCounter.max_strikes_reached -> (forwarded) HUD.stage_failed

# signal passenger_time_up(passenger)
signal stage_failed
signal level_completed_continued
signal stage_retry_requested

@onready var dialogue_bubble = $DialogueBubble
@onready var queue_panel = $QueuePanel
@onready var strike_counter = $TopBar/StrikeCounter
@onready var timer_panel = $TopBar/QuotaPanel  # repurposed as a countdown timer, see quota_panel.gd
@onready var stage_banner = $StageBanner
@onready var notification_area = $NotificationArea
@onready var tooltip = $Tooltip
@onready var level_completion_popup = $LevelCompletionPopup
@onready var pause_menu = $PauseMenu
@onready var game_over_popup = $GameOverPopup
@onready var pause_button = $TopBar/PauseButton

var _active_passenger: Passenger = null

func _ready() -> void:
	queue_panel.passenger_focused.connect(_on_passenger_focused)
	strike_counter.max_strikes_reached.connect(func(): emit_signal("stage_failed"))
	level_completion_popup.continue_pressed.connect(func(): level_completed_continued.emit())
	pause_button.pressed.connect(_on_pause_button_pressed)
	game_over_popup.retry_pressed.connect(func(): stage_retry_requested.emit())
	pause_menu.pause_toggled.connect(_on_pause_toggled)

# --- Stage lifecycle ---

func start_stage(stage_title: String, passengers: Array[Passenger], time_limit_sec: float) -> void:
	stage_banner.show_stage(stage_title)
	queue_panel.populate(passengers)
	timer_panel.start_timer(time_limit_sec)
	strike_counter.reset()

## Called every frame by GameManager while a stage is running
func update_timer(seconds_remaining: float) -> void:
	timer_panel.update_time(seconds_remaining)

## Called once when a stage ends 
func show_stage_result(stars: int, cleared_early: bool) -> void:
	var star_str := "★".repeat(stars) + "☆".repeat(3 - stars)
	var headline := "Sakay lahat!" if cleared_early else "Oras na!"
	stage_banner.show_stage("%s  %s" % [headline, star_str], 2.5)

func on_rule_violated() -> void:
	strike_counter.add_strike()
	notification_area.push("Kuya, paki-check po!", "error")

func on_rule_satisfied(clue_text: String = "") -> void:
	notification_area.push("Satisfied: %s" % clue_text if clue_text else "Rule satisfied!", "success")

# --- Rule validation ---
# NOTE: unhappy/happy state used to also push each complaint string here as
# a toast (notification_area.push(complaint, "error")). That's now shown as
# the Check/Cross emote popping above the seated card instead -- see
# GameManager._broadcast_seat_feedback() / PassengerCard.show_feedback().
# Kept this function (rather than deleting call sites) in case we want to
# resurface complaint text elsewhere later, e.g. in a tooltip on the emote.
func apply_validation_report(report: Dictionary) -> void:
	pass

# --- Passenger interaction ---

## Call when a character (seated or in queue) is clicked
func inspect_passenger(passenger: Passenger, world_or_ui_position: Vector2) -> void:
	GameManager.play_sfx("dialogue")
	dialogue_bubble.point_at(world_or_ui_position)
	dialogue_bubble.set_from_passenger(passenger)

func advance_queue() -> void:
	queue_panel.advance()

# --- Tooltip helpers ---

func show_tooltip_for(text: String) -> void:
	tooltip.show_tooltip(text)

func hide_tooltip() -> void:
	tooltip.hide_tooltip()

# --- Internal ---

func _on_passenger_focused(passenger: Passenger) -> void:
	_active_passenger = passenger
	dialogue_bubble.set_from_passenger(passenger)
	GameManager.play_sfx("dialogue")

func show_level_complete_popup(level_title: String) -> void:
	level_completion_popup.show_popup(level_title)
	_hide_keyboard_selector()

func show_game_over_popup() -> void:
	game_over_popup.show_popup()
	_hide_keyboard_selector()

func _on_pause_button_pressed() -> void:
	pause_menu.toggle_pause()

func set_pause_button_state(is_paused: bool) -> void:
	var sprite_node = get_node_or_null("TopBar/PauseButton/PauseSprite")
	if is_instance_valid(sprite_node) and sprite_node is AnimatedSprite2D:
		sprite_node.frame = 3 if is_paused else 0

func _on_pause_toggled(is_paused: bool) -> void:
	set_pause_button_state(is_paused)
	var selector = get_node_or_null("KeyboardSelectorCursor")
	if selector:
		if is_paused:
			selector.hide()
		else:
			var parent_node = get_parent()
			if parent_node and parent_node.has_method("_update_selector_position"):
				parent_node._update_selector_position()

func _hide_keyboard_selector() -> void:
	var selector = get_node_or_null("KeyboardSelectorCursor")
	if selector:
		selector.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not game_over_popup.visible and not level_completion_popup.visible:
			_on_pause_button_pressed()
			get_viewport().set_input_as_handled()
