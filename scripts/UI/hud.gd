extends CanvasLayer
## Scripts/UI/hud.gd
## Top-level container for every Dev 3 system. Other devs should mostly
## talk to HUD's public methods/signals rather than reaching into child
## nodes directly — keeps the integration surface small and stable.
##
## v2 (time + star rating, quota removed):
##   - QuotaPanel is repurposed as the stage countdown timer -- see
##     quota_panel.gd. Same node, different meaning, no .tscn changes.
##   - on_fare_collected() removed, fare/quota system retired.
##   - Added update_timer() and show_stage_result() for GameManager to call.
##   - Stage completion is decided entirely by GameManager now (everyone
##     happy = cleared early, timer hits zero = time's up) -- this file no
##     longer emits stage_cleared itself.
##
## Wiring done here:
##   QueuePanel.passenger_focused      -> DialogueBubble.set_from_passenger
##   StrikeCounter.max_strikes_reached -> (forwarded) HUD.stage_failed

signal passenger_time_up(passenger)
signal stage_failed

@onready var dialogue_bubble = $DialogueBubble
@onready var queue_panel = $QueuePanel
@onready var strike_counter = $TopBar/StrikeCounter
@onready var timer_panel = $TopBar/QuotaPanel  # repurposed as a countdown timer, see quota_panel.gd
@onready var stage_banner = $StageBanner
@onready var notification_area = $NotificationArea
@onready var tooltip = $Tooltip

var _active_passenger: Passenger = null

func _ready() -> void:
	queue_panel.passenger_focused.connect(_on_passenger_focused)
	strike_counter.max_strikes_reached.connect(func(): emit_signal("stage_failed"))

# --- Stage lifecycle (Dev 4 calls these) -----------------------------------

func start_stage(stage_title: String, passengers: Array[Passenger], time_limit_sec: float) -> void:
	stage_banner.show_stage(stage_title)
	queue_panel.populate(passengers)
	timer_panel.start_timer(time_limit_sec)
	strike_counter.reset()

## Called every frame by GameManager while a stage is running.
func update_timer(seconds_remaining: float) -> void:
	timer_panel.update_time(seconds_remaining)

## Called once when a stage ends (cleared early or timed out) with its
## final star rating. Reuses StageBanner rather than needing new UI.
func show_stage_result(stars: int, cleared_early: bool) -> void:
	var star_str := "★".repeat(stars) + "☆".repeat(3 - stars)
	var headline := "Sakay lahat!" if cleared_early else "Oras na!"
	stage_banner.show_stage("%s  %s" % [headline, star_str], 2.5)

func on_rule_violated() -> void:
	strike_counter.add_strike()
	notification_area.push("Kuya, paki-check po!", "error")

func on_rule_satisfied(clue_text: String = "") -> void:
	notification_area.push("Satisfied: %s" % clue_text if clue_text else "Rule satisfied!", "success")

# --- Rule validation (Dev 1's RuleValidator.validate(grid) return value) ---
# Report shape, from rule_validator.gd:
#   { "is_valid": bool, "violated_rules": Array[String],
#     "passenger_status": { p.id: { "is_happy": bool, "complaints": Array } } }
#
# CAUTION (flagged by Copilot on Dev 1's PR, applies here too): the report
# is keyed by passenger.id. If two passengers share an id, or a Passenger
# is left with the default empty id, their statuses collapse into one
# entry and this function will show/attribute the wrong complaints. Don't
# rely on id uniqueness in UI code beyond this bridge until Dev 1 confirms
# ids are guaranteed unique (e.g. assigned at spawn time, not hand-typed
# per Resource).
func apply_validation_report(report: Dictionary) -> void:
	for p_id in report.passenger_status:
		var status: Dictionary = report.passenger_status[p_id]
		if not status["is_happy"]:
			for complaint in status["complaints"]:
				notification_area.push(complaint, "error")
	# NOTE: this used to also emit stage_cleared when report.is_valid was
	# true. Stage completion is now GameManager's call entirely (everyone
	# happy = cleared early, timer hits zero = time's up), so this
	# function's only job is surfacing complaints as toasts.

# --- Passenger interaction (Dev 2 calls these) -----------------------------

## Call when a character (seated or in queue) is clicked, per the
## click-to-inspect pattern.
func inspect_passenger(passenger: Passenger, world_or_ui_position: Vector2) -> void:
	GameManager.play_sfx("dialogue")
	dialogue_bubble.point_at(world_or_ui_position)
	dialogue_bubble.set_from_passenger(passenger)

func advance_queue() -> void:
	queue_panel.advance()

# --- Tooltip helpers (any UI element with mouse_entered/exited) ------------

func show_tooltip_for(text: String) -> void:
	tooltip.show_tooltip(text)

func hide_tooltip() -> void:
	tooltip.hide_tooltip()

# --- internal ---------------------------------------------------------------

func _on_passenger_focused(passenger: Passenger) -> void:
	_active_passenger = passenger
	dialogue_bubble.set_from_passenger(passenger)
	GameManager.play_sfx("dialogue")
