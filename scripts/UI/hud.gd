extends CanvasLayer
## Scripts/UI/hud.gd
## Top-level container for every Dev 3 system. Other devs should mostly
## talk to HUD's public methods/signals rather than reaching into child
## nodes directly — keeps the integration surface small and stable.
##
## Wiring done here:
##   QueuePanel.passenger_focused  -> DialogueBubble.set_from_passenger
##   AngerBar.depleted             -> (forwarded) HUD.passenger_time_up
##   StrikeCounter.max_strikes_reached -> (forwarded) HUD.stage_failed
##   QuotaPanel.quota_met          -> (forwarded) HUD.stage_cleared

signal passenger_time_up(passenger)
signal stage_failed
signal stage_cleared

@onready var dialogue_bubble = $DialogueBubble
@onready var queue_panel = $QueuePanel
@onready var strike_counter = $TopBar/StrikeCounter
@onready var quota_panel = $TopBar/QuotaPanel
@onready var stage_banner = $StageBanner
@onready var notification = $NotificationArea
@onready var tooltip = $Tooltip

var _active_passenger: Passenger = null

func _ready() -> void:
	queue_panel.passenger_focused.connect(_on_passenger_focused)
	strike_counter.max_strikes_reached.connect(func(): emit_signal("stage_failed"))
	quota_panel.quota_met.connect(func(): emit_signal("stage_cleared"))

# --- Stage lifecycle (Dev 4 calls these) -----------------------------------

func start_stage(stage_title: String, passengers: Array[Passenger], quota_target: float) -> void:
	stage_banner.show_stage(stage_title)
	queue_panel.populate(passengers)
	quota_panel.set_quota(quota_target)
	strike_counter.reset()

func on_fare_collected(amount: float) -> void:
	quota_panel.add_fare(amount)

func on_rule_violated() -> void:
	strike_counter.add_strike()
	notification.push("Kuya, paki-check po!", "error")

func on_rule_satisfied(clue_text: String = "") -> void:
	notification.push("Satisfied: %s" % clue_text if clue_text else "Rule satisfied!", "success")

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
				notification.push(complaint, "error")
	if report.is_valid:
		emit_signal("stage_cleared")

# --- Passenger interaction (Dev 2 calls these) -----------------------------

## Call when a character (seated or in queue) is clicked, per the
## click-to-inspect pattern.
func inspect_passenger(passenger: Passenger, world_or_ui_position: Vector2) -> void:
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
