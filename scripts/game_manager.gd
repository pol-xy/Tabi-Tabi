extends Node
## scripts/game_manager.gd
## AUTOLOAD (Singleton) — register as "GameManager" in Project Settings > Autoload.
##
## v2: Time-based stages + star rating, replacing the old Daily Quota system.
##   - Each stage has a fixed time_limit_sec instead of a quota_target.
##   - A stage ends when everyone is happily seated (cleared early) OR when
##     time runs out.
##   - Star rating (0-3):
##       Cleared early  -> based on how much time was used (speed).
##       Time ran out    -> based on the fraction of the roster seated & happy.
##     Either way, each anger-meter-depletion penalty (trigger_penalty)
##     subtracts one star from the result, clamped at 0.
##
## Integration points:
##   - main_jeepney.gd calls register_hud(), register_grid(),
##     register_seat_nodes(), then start_campaign().
##   - Dev 2's seat_1.gd calls on_passenger_seated(passenger) after a
##     successful place_passenger().
##   - Whoever wires an AngerBar's `depleted` signal (per queue card, or a
##     Holdaper boarding-window timer) calls trigger_penalty(passenger) --
##     that's the single entry point for the "anger meter hit zero" case.
##
## NOTE ON HUD COMPATIBILITY: hud.gd may have changed since this script was
## written (your team's feat/UI branch). Calls to brand-new HUD methods
## (update_timer, show_stage_result) are guarded with has_method() so this
## script won't crash against an older or newer HUD -- worst case, the
## timer/result just won't visually display until HUD adds those methods.
## hud.start_stage(title, passengers, X) and hud.apply_validation_report()
## are assumed to still exist, since those predate this change.

signal campaign_complete
signal campaign_failed(stage_index: int)
signal stage_result(stage_index: int, stars: int, cleared_early: bool)

const STAGE_CLEAR_PAUSE_SEC := 1.5

var current_stage_index: int = -1
var current_grid: JeepneyGrid = null
var hud: Node = null

var stages: Array = []
var _current_roster_size: int = 0
var _stage_finishing: bool = false
var _seat_nodes: Array = []

# --- Timer state ---------------------------------------------------------
var _time_limit: float = 0.0
var _time_remaining: float = 0.0
var _timer_active: bool = false

# --- Penalty state (anger meter depletions this stage) --------------------
var _penalty_count: int = 0

func _ready() -> void:
	stages = [
		{
			"title": "Stage 1 — Morning Rush I",
			"time_limit_sec": 120.0,
			"passengers": _build_stage_1_roster(),
		},
		{
			"title": "Stage 2 — Morning Rush II",
			"time_limit_sec": 150.0,
			"passengers": _build_stage_2_roster(),
		},
		{
			"title": "Stage 3 — Night Shift",
			"time_limit_sec": 150.0,
			"passengers": _build_stage_3_roster(),
		},
	]

func _process(delta: float) -> void:
	if not _timer_active:
		return
	_time_remaining -= delta
	_notify_timer_update()
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_timer_active = false
		_end_stage_by_timeout()

# --- Called once by main_jeepney.gd -----------------------------------------

func register_hud(hud_node: Node) -> void:
	hud = hud_node
	if hud.stage_failed.is_connected(_on_stage_failed):
		return
	hud.stage_failed.connect(_on_stage_failed)
	# NOTE: stage_failed/campaign_failed is currently dormant -- nothing
	# calls hud.on_rule_violated() to build strikes anymore under the new
	# time/star design. Left wired in case the team wants a hard-fail
	# condition back later.

func register_grid(grid_node: JeepneyGrid) -> void:
	current_grid = grid_node

## Needed so a fresh stage can wipe leftover passenger cards left sitting
## in seats from the previous stage -- clear_grid() only resets the
## logical data, not whatever's still visually parented there.
func register_seat_nodes(seats: Array) -> void:
	_seat_nodes = seats

func start_campaign() -> void:
	current_stage_index = -1
	_advance_stage()

## Read-only helper for Dev 2/3 -- e.g. to stop accepting drag-drops once
## time's up or while the clear animation is playing.
func is_stage_active() -> bool:
	return _timer_active and not _stage_finishing

# --- Called by Dev 2's seat script, every time a passenger is dropped -------
# (also fires on reshuffles -- that's intentional, it's how we notice the
# player fixed a problem.)

func on_passenger_seated(passenger: Passenger) -> void:
	if current_grid == null or passenger == null or _stage_finishing:
		return

	if hud and hud.queue_panel:
		hud.queue_panel.detach_passenger(passenger)

	var report: Dictionary = RuleValidator.validate(current_grid)
	if hud:
		hud.apply_validation_report(report)

	var seated_count: int = current_grid.get_unique_passengers().size()
	if seated_count >= _current_roster_size and _current_roster_size > 0:
		_try_finish_stage(report)

# --- The anger-meter penalty trigger ----------------------------------------
## Single entry point for "a passenger's anger meter hit zero" (queue-side
## impatience, or a Holdaper boarding-window timer). Per the new design
## this no longer causes an instant fail -- it just costs a star at the
## end of the stage, and removes that passenger from their seat if seated.

func trigger_penalty(passenger: Passenger) -> void:
	_penalty_count += 1
	_notify("Isang pasahero ang nainis at bumaba na. (-1 star)", "error")
	if current_grid and passenger != null:
		current_grid.remove_passenger(passenger)

# --- Stage flow ---------------------------------------------------------

func _advance_stage() -> void:
	current_stage_index += 1
	if current_stage_index >= stages.size():
		_timer_active = false
		emit_signal("campaign_complete")
		return

	var stage: Dictionary = stages[current_stage_index]
	_current_roster_size = stage["passengers"].size()
	_stage_finishing = false
	_penalty_count = 0
	_time_limit = stage["time_limit_sec"]
	_time_remaining = _time_limit
	_timer_active = true

	if current_grid:
		current_grid.clear_grid()
	_clear_seat_visuals()

	if hud:
		hud.start_stage(stage["title"], stage["passengers"], stage["time_limit_sec"])
	_notify_timer_update()

## Frees any passenger cards still visually parented under a seat from the
## previous stage (they were reparented there by seat_1.gd on drop).
func _clear_seat_visuals() -> void:
	for seat in _seat_nodes:
		if seat == null:
			continue
		for child in seat.get_children():
			child.queue_free()

## Checked every time the roster is fully seated. Only ends the stage (and
## awards speed-based stars) once everyone is actually happy -- otherwise
## the player keeps reshuffling for free, same as before, just now racing
## the clock instead of a quota.
func _try_finish_stage(report: Dictionary) -> void:
	var unhappy := 0
	for p_id in report.get("passenger_status", {}):
		if not report.passenger_status[p_id]["is_happy"]:
			unhappy += 1

	if unhappy > 0:
		return  # stay on this stage; complaints already shown via apply_validation_report

	_timer_active = false
	_stage_finishing = true

	var elapsed: float = _time_limit - _time_remaining
	var stars: int = _stars_from_speed(elapsed, _time_limit)
	stars = max(stars - _penalty_count, 0)

	_notify("Stage cleared! %s" % _star_string(stars), "success")
	_report_stage_result(stars, true)

	await get_tree().create_timer(STAGE_CLEAR_PAUSE_SEC).timeout
	_advance_stage()

## Time ran out before everyone was seated & happy.
func _end_stage_by_timeout() -> void:
	if _stage_finishing:
		return
	_stage_finishing = true

	var happy_count := 0
	if current_grid:
		var report: Dictionary = RuleValidator.validate(current_grid)
		for p_id in report.get("passenger_status", {}):
			if report.passenger_status[p_id]["is_happy"]:
				happy_count += 1

	var stars: int = _stars_from_completion(happy_count, _current_roster_size)
	stars = max(stars - _penalty_count, 0)

	_notify("Oras na! %s" % _star_string(stars), "error")
	_report_stage_result(stars, false)

	await get_tree().create_timer(STAGE_CLEAR_PAUSE_SEC).timeout
	_advance_stage()

func _on_stage_failed() -> void:
	emit_signal("campaign_failed", current_stage_index)

# --- Star rating helpers -------------------------------------------------

func _stars_from_speed(elapsed: float, time_limit: float) -> int:
	if time_limit <= 0.0:
		return 3
	var ratio: float = elapsed / time_limit
	if ratio <= 0.5:
		return 3
	elif ratio <= 0.75:
		return 2
	else:
		return 1

func _stars_from_completion(happy_count: int, total: int) -> int:
	if total <= 0:
		return 0
	var frac: float = float(happy_count) / total
	if frac >= 1.0:
		return 3
	elif frac >= 0.6:
		return 2
	elif frac > 0.0:
		return 1
	else:
		return 0

func _star_string(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)

func _report_stage_result(stars: int, cleared_early: bool) -> void:
	emit_signal("stage_result", current_stage_index, stars, cleared_early)
	if hud and hud.has_method("show_stage_result"):
		hud.show_stage_result(stars, cleared_early)

# --- Defensive HUD helpers (safe against HUD not having caught up yet) ----

func _notify_timer_update() -> void:
	if hud and hud.has_method("update_timer"):
		hud.update_timer(_time_remaining)

func _notify(text: String, type: String = "info") -> void:
	if hud and "notification_area" in hud and hud.notification_area != null:
		hud.notification_area.push(text, type)

# --- Roster builders (unchanged from before) ------------------------------

func _make(id: String, name: String, overrides: Dictionary) -> Passenger:
	var p := Passenger.new()
	p.id = id
	p.passenger_name = name
	for key in overrides:
		if key in p:
			p.set(key, overrides[key])
	return p

func _build_stage_1_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("s1_jb_suarez", "JB Suarez", {"is_noisy": true,
		"monologue_text": "Sigaw nang sigaw kapag may kamote"}))
	list.append(_make("s1_market_goer", "Market Goer", {"is_heavy_load": true,
		"monologue_text": "Maraming bitbit galing palengke"}))
	list.append(_make("s1_student", "Student", {"is_student": true, "is_introvert": true,
		"monologue_text": "Shy type"}))
	list.append(_make("s1_regular_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Asim kilig"}))
	list.append(_make("s1_regular_normal", "Regular Commuter", {"monologue_text": "Papunta sa paroroonan"}))
	return list

func _build_stage_2_roster() -> Array[Passenger]:
	var list: Array[Passenger] = _build_stage_1_roster()
	list.append(_make("s2_balikbayan", "Balikbayan", {"is_heavy_load": true, "seat_size_passenger": 2, "destination_stop": 1,
		"monologue_text": "Sobrang dami kong dala, kaka-alis ko lang sa airport."}))
	var lover_a := _make("s2_lover_a", "Lovey Dovey A", {"is_companion": true, "companion_id": "s2_lover_b",
		"monologue_text": "Sana magkatabi kami ng jowa ko, promise ko tahimik lang."})
	var lover_b := _make("s2_lover_b", "Lovey Dovey B", {"is_companion": true, "companion_id": "s2_lover_a",
		"monologue_text": "Kasama ko siya, dapat magkatabi o magkaharap kami."})
	list.append(lover_a)
	list.append(lover_b)
	return list

func _build_stage_3_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	# is_white_lady must be true here, not just a low anger_meter_max --
	# PassengerCard's anger-meter check treats her as innately impatient
	# via this flag, regardless of is_impatient.
	list.append(_make("s3_white_lady", "White Lady", {"is_white_lady": true, "anger_meter_max": 25.0,
		"monologue_text": "...sandali lang sasakay ako."}))
	# Holdaper's boarding-window pressure reuses the same opt-in anger meter
	# (is_impatient) rather than a separate timer system -- a short
	# anger_meter_max IS his "must reach the front seat in time" window.
	list.append(_make("s3_holdaper", "Suspicious Passenger", {"is_holdaper": true, "is_impatient": true, "anger_meter_max": 20.0,
		"monologue_text": "Sa harap na lang ako, malapit sa driver."}))
	list.append(_make("s3_drunk", "Drunk Man", {"is_noisy": true, "is_drunk_man": true,
		"monologue_text": "Woohoo! Kanta tayo pare!"}))
	list.append(_make("s3_regular", "Regular Commuter", {}))
	return list
