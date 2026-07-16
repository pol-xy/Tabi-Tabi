extends Node
## scripts/game_manager.gd
## AUTOLOAD (Singleton) — register this as "GameManager" in
## Project Settings > Autoload before running.
##
## Owns: the 3-stage campaign loop, quota-vs-fare tracking, and the
## "1-2-3" penalty trigger. This is the piece described as Dev 4's job in
## the team doc — nothing else in the repo builds this, so it's a clean
## gap for us to fill.
##
## Integration points (who calls what):
##   - main_jeepney.gd (attached to Main_Jeepney root) calls register_hud(),
##     register_grid(), then start_campaign() once, on scene ready.
##   - Dev 2's seat_1.gd calls on_passenger_seated(passenger) right after
##     jeepney_grid.place_passenger(...) succeeds.
##   - Whoever wires an AngerBar's `depleted` signal (per queue card, or
##     Holdaper's boarding-window timer) should call
##     trigger_penalty(passenger) — that's the single "1-2-3" entry point.

signal campaign_complete
signal campaign_failed(stage_index: int)

const BASE_FARE := 15.0
const STAGE_CLEAR_PAUSE_SEC := 1.5

var current_stage_index: int = -1
var current_grid: JeepneyGrid = null
var hud: Node = null

var stages: Array = []
var _current_roster_size: int = 0
var _fare_paid_ids: Dictionary = {}
var _stage_finishing: bool = false
var _seat_nodes: Array = []

func _ready() -> void:
	stages = [
		{
			"title": "Stage 1 — Morning Rush I",
			"quota_target": 60.0,
			"passengers": _build_stage_1_roster(),
		},
		{
			"title": "Stage 2 — Morning Rush II",
			"quota_target": 130.0,
			"passengers": _build_stage_2_roster(),
		},
		{
			"title": "Stage 3 — Night Shift",
			"quota_target": 170.0,
			"passengers": _build_stage_3_roster(),
		},
	]

# --- Called once by main_jeepney.gd -----------------------------------------

func register_hud(hud_node: Node) -> void:
	hud = hud_node
	if not hud.stage_failed.is_connected(_on_stage_failed):
		hud.stage_failed.connect(_on_stage_failed)
	# NOTE: hud.stage_cleared (fed by quota_panel.quota_met) is intentionally
	# NOT connected here anymore. Per the GDD, the stage pass condition is
	# the happiness threshold once everyone is seated -- fare/quota only
	# feeds the end-of-stage rating, it doesn't gate progression. See
	# on_passenger_seated() / _finish_stage() below.

func register_grid(grid_node: JeepneyGrid) -> void:
	current_grid = grid_node

## Called once by main_jeepney.gd with the seat Control nodes (the ones
## running seat_1.gd). Needed so a fresh stage can wipe leftover passenger
## cards left sitting in seats from the previous stage -- clear_grid() only
## resets the logical data, not whatever's still visually parented there.
func register_seat_nodes(seats: Array) -> void:
	_seat_nodes = seats

func start_campaign() -> void:
	current_stage_index = -1
	_advance_stage()

# --- Called by Dev 2's seat script, every time a passenger is dropped -------
# (this also fires on reshuffles, since re-dropping a seated passenger is
# just another place_passenger call -- that's intentional, it's how we
# notice the player fixed a problem.)

func on_passenger_seated(passenger: Passenger) -> void:
	if current_grid == null or passenger == null or _stage_finishing:
		return

	if hud and hud.queue_panel:
		hud.queue_panel.detach_passenger(passenger)

	var report: Dictionary = RuleValidator.validate(current_grid)
	if hud:
		hud.apply_validation_report(report)

	var status: Dictionary = report.get("passenger_status", {}).get(passenger.id, {})
	var is_happy: bool = status.get("is_happy", true)

	if is_happy:
		_collect_fare(passenger)
	else:
		if hud:
			hud.on_rule_violated()

	var seated_count: int = current_grid.get_unique_passengers().size()
	if seated_count >= _current_roster_size and _current_roster_size > 0:
		_try_finish_stage(report)

# --- The "1-2-3" penalty trigger --------------------------------------------
## Single entry point for anger-meter-depleted / Holdaper-window-expired /
## any other "ran out the clock on this passenger" case. Wire AngerBar's
## `depleted` signal (or a Holdaper timer) to call this.

func trigger_penalty(passenger: Passenger) -> void:
	if hud:
		hud.on_rule_violated()
	if current_grid and passenger != null:
		current_grid.remove_passenger(passenger)
	# Intentionally NOT removing the passenger card from the queue here --
	# whoever wires this (queue vs. seated case) should also call
	# hud.queue_panel.remove_passenger(passenger) if it's a queue timeout,
	# since only they know which context triggered it.

# --- Stage flow ---------------------------------------------------------

func _advance_stage() -> void:
	current_stage_index += 1
	if current_stage_index >= stages.size():
		emit_signal("campaign_complete")
		return

	var stage: Dictionary = stages[current_stage_index]
	_current_roster_size = stage["passengers"].size()
	_fare_paid_ids.clear()
	_stage_finishing = false
	if current_grid:
		current_grid.clear_grid()
	_clear_seat_visuals()
	if hud:
		hud.start_stage(stage["title"], stage["passengers"], stage["quota_target"])

## Frees any passenger cards still visually parented under a seat from the
## previous stage (they were reparented there by seat_1.gd on drop).
func _clear_seat_visuals() -> void:
	for seat in _seat_nodes:
		if seat == null:
			continue
		for child in seat.get_children():
			child.queue_free()

## Called once every seat in the roster is filled. Everyone being able to
## freely reshuffle at no cost (per the GDD) means we don't force-advance
## here if the group isn't happy yet -- we just let the player keep
## rearranging. Re-dropping a passenger re-runs on_passenger_seated(), so
## this check re-fires automatically after every reshuffle attempt.
func _try_finish_stage(report: Dictionary) -> void:
	var unhappy := 0
	for p_id in report.get("passenger_status", {}):
		if not report.passenger_status[p_id]["is_happy"]:
			unhappy += 1

	if unhappy > 0:
		if hud:
			hud.on_rule_violated()  # counts as a strike-worthy attempt
		return  # stay on this stage; player keeps reshuffling for free

	_stage_finishing = true
	if hud:
		hud.on_rule_satisfied("Stage cleared!")
	await get_tree().create_timer(STAGE_CLEAR_PAUSE_SEC).timeout
	_advance_stage()

func _on_stage_failed() -> void:
	emit_signal("campaign_failed", current_stage_index)
	# TODO: hook up a retry / game-over screen once art/UI exists for one.
	# For now this just stops the loop so the failure is visible in-game.

func _collect_fare(passenger: Passenger) -> void:
	if _fare_paid_ids.has(passenger.id):
		return  # already paid this stage -- don't double-charge on reshuffle
	_fare_paid_ids[passenger.id] = true
	var fare := BASE_FARE
	if passenger.is_heavy_load or passenger.seat_size_passenger > 1:
		fare += 5.0  # cargo surcharge, tune later
	if hud:
		hud.on_fare_collected(fare)

# --- Placeholder rosters ------------------------------------------------
## These exist so the game is playable end-to-end TODAY. Swap the
## monologue_text / names for the real content once it's off Trello —
## nothing else needs to change, HUD/grid/validator all read from the
## same Passenger fields.

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
	list.append(_make("s3_white_lady", "White Lady", {"anger_meter_max": 25.0,
		"monologue_text": "...sandali lang sasakay ako."}))
	list.append(_make("s3_holdaper", "Suspicious Passenger", {"is_holdaper": true, "anger_meter_max": 20.0,
		"monologue_text": "Sa harap na lang ako, malapit sa driver."}))
	list.append(_make("s3_drunk", "Drunk Man", {"is_noisy": true,
		"monologue_text": "Woohoo! Kanta tayo pare!"}))
	list.append(_make("s3_regular", "Regular Commuter", {}))
	return list

func _make(id: String, name: String, overrides: Dictionary) -> Passenger:
	var p := Passenger.new()
	p.id = id
	p.passenger_name = name
	for key in overrides:
		if key in p:
			p.set(key, overrides[key])
	return p
