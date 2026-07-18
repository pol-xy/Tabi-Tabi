extends Node
## scripts/game_manager.gd

signal campaign_complete
signal campaign_failed(level_index: int, stage_index: int)
signal level_started(level_index: int)
signal stage_result(level_index: int, stage_index: int, stars: int, cleared_early: bool)

const STAGE_CLEAR_PAUSE_SEC := 1.5

var current_level_index: int = -1
var current_stage_index: int = -1
var current_grid: JeepneyGrid = null
var hud: Node = null
var background: Node = null
var jeep_exterior: Node = null

var levels: Array = []
var _current_roster_size: int = 0
var _stage_finishing: bool = false
var _seat_nodes: Array = []

# --- Timer state ---------------------------------------------------------
var _time_limit: float = 0.0
var _time_remaining: float = 0.0
var _timer_active: bool = false

# --- Penalty state (anger meter depletions this stage) --------------------
var _penalty_count: int = 0

# --- Audio state ---------------------------------------------------------
var _bgm_player: AudioStreamPlayer = null

var sound_paths: Dictionary = {
	"day_theme": "res://Assets/Sounds/MainSFX/Day Theme.ogg",
	"game_over": "res://Assets/Sounds/MainSFX/Game Over.ogg",
	"level_completed": "res://Assets/Sounds/MainSFX/Level Completed.ogg",
	"levels": "res://Assets/Sounds/MainSFX/Levels.ogg",
	"main_menu": "res://Assets/Sounds/MainSFX/Main Menu.ogg",
	"night_theme": "res://Assets/Sounds/MainSFX/Night Theme.ogg",
	"transition": "res://Assets/Sounds/MainSFX/Transition.ogg",
	
	"click_select": "res://Assets/Sounds/UI SFX/Click slect.wav",
	"correct_seat": "res://Assets/Sounds/UI SFX/Correct seat.wav",
	"dialogue": "res://Assets/Sounds/UI SFX/Dialogue.wav",
	"drag_passenger": "res://Assets/Sounds/UI SFX/Drag passenger.wav",
	"wrong_seat": "res://Assets/Sounds/UI SFX/Wrong seat.wav"
}

var sounds: Dictionary = {}

func get_sound(stream_name: String) -> AudioStream:
	if sounds.has(stream_name):
		return sounds[stream_name]
	if sound_paths.has(stream_name):
		var path = sound_paths[stream_name]
		if ResourceLoader.exists(path):
			var stream = load(path)
			sounds[stream_name] = stream
			return stream
	return null

func play_bgm(stream_name: String) -> void:
	var stream = get_sound(stream_name)
	if stream == null:
		return
	
	# Ensure BGM loops forever so it doesn't stop during long level sessions
	if "loop" in stream:
		stream.loop = true
		
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.play()

func stop_bgm() -> void:
	if _bgm_player:
		_bgm_player.stop()

func play_sfx(stream_name: String) -> void:
	var stream = get_sound(stream_name)
	if stream == null:
		return
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.bus = "SFX"
	
	# Tuning specific SFX volumes
	match stream_name:
		"transition":
			player.volume_db = -10.0
		"drag_passenger":
			player.volume_db = -12.0
		"click_select":
			player.volume_db = -8.0
		"correct_seat", "wrong_seat", "dialogue":
			player.volume_db = -4.0
			
	player.play()
	player.finished.connect(func(): player.queue_free())

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)
	
	play_bgm("main_menu")
	
	levels = [
		{
			"title": "Level 1 — Ang Unang Byahe",
			"rows": 2,
			"cols": 4,
			"stages": [
				{
					"title": "Puzzle 1.1 — Priority & Tagabot",
					"time_limit_sec": 90.0,
					"passengers": _build_l1_s1_roster(),
					"jeep_variant": 4,
				},
				{
					"title": "Puzzle 1.2 — Heavy Loads & Rushers",
					"time_limit_sec": 110.0,
					"passengers": _build_l1_s2_roster(),
					"jeep_variant": 5,
				},
				{
					"title": "Puzzle 1.3 — Night Shift & Personal Space",
					"time_limit_sec": 110.0,
					"passengers": _build_l1_s3_roster(),
					"is_night": true,
					"jeep_variant": 6,
				},
			],
		},
		{
			"title": "Level 2 — The Scent and Sound",
			"rows": 2,
			"cols": 5,
			"stages": [
				{
					"title": "Puzzle 2.1 — Morning Rush 1",
					"time_limit_sec": 130.0,
					"passengers": _build_l2_s1_roster(),
					"jeep_variant": 1,
				},
				{
					"title": "Puzzle 2.2 — Morning Rush 2",
					"time_limit_sec": 140.0,
					"passengers": _build_l2_s2_roster(),
					"jeep_variant": 2,
				},
				{
					"title": "Puzzle 2.3 — Night Shift 2",
					"time_limit_sec": 140.0,
					"passengers": _build_l2_s3_roster(),
					"is_night": true,
					"jeep_variant": 3,
				},
			],
		},
		{
			"title": "Level 3 — Full House Logic",
			"rows": 2,
			"cols": 5,
			"stages": [
				{
					"title": "Puzzle 3.1 — Morning Rush 1 (Full Capacity)",
					"time_limit_sec": 150.0,
					"passengers": _build_l3_s1_roster(),
					"jeep_variant": 1,
				},
				{
					"title": "Puzzle 3.2 — Morning Rush 2 (Full Capacity)",
					"time_limit_sec": 150.0,
					"passengers": _build_l3_s2_roster(),
					"jeep_variant": 2,
				},
				{
					"title": "Puzzle 3.3 — Night Shift 3 (Full Capacity)",
					"time_limit_sec": 160.0,
					"passengers": _build_l3_s3_roster(),
					"is_night": true,
					"jeep_variant": 3,
				},
			],
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
	if not hud.stage_failed.is_connected(_on_stage_failed):
		hud.stage_failed.connect(_on_stage_failed)
	if hud.has_signal("level_completed_continued") and not hud.level_completed_continued.is_connected(_on_level_completed_continued):
		hud.level_completed_continued.connect(_on_level_completed_continued)
	if hud.has_signal("stage_retry_requested") and not hud.stage_retry_requested.is_connected(retry_current_stage):
		hud.stage_retry_requested.connect(retry_current_stage)



func register_grid(grid_node: JeepneyGrid) -> void:
	current_grid = grid_node

func register_background(background_node: Node) -> void:
	background = background_node

func register_jeep_exterior(jeep_node: Node) -> void:
	jeep_exterior = jeep_node

func register_seat_nodes(seats: Array) -> void:
	_seat_nodes = seats

func start_campaign() -> void:
	if current_level_index == -1:
		current_level_index = 0
		
	current_stage_index = 0
	
	emit_signal("level_started", current_level_index)
	_start_current_stage()

func is_stage_active() -> bool:
	return _timer_active and not _stage_finishing

func on_passenger_seated(passenger: Passenger) -> void:
	if current_grid == null or passenger == null or _stage_finishing:
		return

	if hud and hud.queue_panel:
		hud.queue_panel.detach_passenger(passenger)

	var report: Dictionary = RuleValidator.validate(current_grid)
	if hud:
		hud.apply_validation_report(report)

	if report.is_valid:
		play_sfx("correct_seat")
	else:
		play_sfx("wrong_seat")

	var seated_count: int = current_grid.get_unique_passengers().size()
	if seated_count >= _current_roster_size and _current_roster_size > 0:
		_try_finish_stage(report)

func unseat_passenger(passenger: Passenger) -> void:
	if current_grid == null or passenger == null:
		return
	current_grid.remove_passenger(passenger)
	var report: Dictionary = RuleValidator.validate(current_grid)
	if hud:
		hud.apply_validation_report(report)

func trigger_penalty(passenger: Passenger) -> void:
	_penalty_count += 1
	_notify("Isang pasahero ang nainis at bumaba na. (-1 star)", "error")
	if current_grid and passenger != null:
		current_grid.remove_passenger(passenger)

# --- Stage / Level flow ---------------------------------------------------

func _advance_stage() -> void:
	current_stage_index += 1

	var level: Dictionary = _get_level(current_level_index)
	if level.is_empty() or current_stage_index >= level["stages"].size():
		if hud and hud.has_method("show_level_complete_popup"):
			play_bgm("level_completed") # Level completed BGM on popup!
			hud.show_level_complete_popup(level.get("title", "Level"))
		else:
			_advance_level()
		return

	play_sfx("transition") # Transition SFX between stages
	_start_current_stage()

func _advance_level() -> void:
	current_level_index += 1
	current_stage_index = 0

	if current_level_index >= levels.size():
		_timer_active = false
		play_bgm("level_completed")
		emit_signal("campaign_complete")
		return

	emit_signal("level_started", current_level_index)
	_start_current_stage()

func _on_level_completed_continued() -> void:
	play_sfx("transition")
	_advance_level()

func _get_level(index: int) -> Dictionary:
	if index < 0 or index >= levels.size():
		return {}
	return levels[index]

func _start_current_stage() -> void:
	var level: Dictionary = levels[current_level_index]
	var stage: Dictionary = level["stages"][current_stage_index]

	_current_roster_size = stage["passengers"].size()
	_stage_finishing = false
	_penalty_count = 0
	_time_limit = stage["time_limit_sec"]
	_time_remaining = _time_limit
	_timer_active = true

	if stage.get("is_night", false):
		play_bgm("night_theme")
	else:
		play_bgm("day_theme")

	_apply_grid_dimensions(level["rows"], level["cols"])
	_clear_seat_visuals()
	_apply_background_state(stage)
	_apply_jeep_exterior(stage)

	var display_title := "%s — %s" % [level["title"], stage["title"]]
	if hud:
		hud.start_stage(display_title, stage["passengers"], stage["time_limit_sec"])
	_notify_timer_update()

func _apply_grid_dimensions(rows: int, cols: int) -> void:
	if current_grid:
		current_grid.set_dimensions(rows, cols)

	for seat in _seat_nodes:
		if seat == null:
			continue
		var seat_active: bool = seat.grid_row < rows and seat.grid_col < cols
		seat.visible = seat_active

func _apply_background_state(stage: Dictionary) -> void:
	if background and background.has_method("set_night"):
		background.set_night(stage.get("is_night", false))

func _apply_jeep_exterior(stage: Dictionary) -> void:
	if jeep_exterior and jeep_exterior.has_method("set_variant") and stage.has("jeep_variant"):
		jeep_exterior.set_variant(stage["jeep_variant"])

func _clear_seat_visuals() -> void:
	for seat in _seat_nodes:
		if seat == null:
			continue
		for child in seat.get_children():
			child.queue_free()

func _try_finish_stage(report: Dictionary) -> void:
	var unhappy := 0
	for p_id in report.get("passenger_status", {}):
		if not report.passenger_status[p_id]["is_happy"]:
			unhappy += 1

	if unhappy > 0:
		return  # complaints already shown via apply_validation_report

	_timer_active = false
	_stage_finishing = true

	var elapsed: float = _time_limit - _time_remaining
	var stars: int = _stars_from_speed(elapsed, _time_limit)
	stars = max(stars - _penalty_count, 0)

	_notify("Stage cleared! %s" % _star_string(stars), "success")
	_report_stage_result(stars, true)
	play_sfx("transition")

	await get_tree().create_timer(STAGE_CLEAR_PAUSE_SEC).timeout
	_advance_stage()

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
	play_bgm("game_over")

	await get_tree().create_timer(STAGE_CLEAR_PAUSE_SEC).timeout
	if hud and hud.has_method("show_game_over_popup"):
		hud.show_game_over_popup()
	else:
		_advance_stage()

func _on_stage_failed() -> void:
	play_bgm("game_over")
	emit_signal("campaign_failed", current_level_index, current_stage_index)

func retry_current_stage() -> void:
	_stage_finishing = false
	_penalty_count = 0
	_time_remaining = _time_limit
	
	if current_grid:
		current_grid.clear_grid()
	_clear_seat_visuals()
	
	if current_level_index >= 0 and current_level_index < levels.size():
		var level = levels[current_level_index]
		var stage = level["stages"][current_stage_index]
		_apply_background_state(stage)
		_apply_jeep_exterior(stage)
		
		if stage.get("is_night", false):
			play_bgm("night_theme")
		else:
			play_bgm("day_theme")
			
		var display_title := "%s — %s" % [level["title"], stage["title"]]
		if hud:
			hud.start_stage(display_title, stage["passengers"], stage["time_limit_sec"])
			
	_timer_active = true
	_notify_timer_update()

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
	emit_signal("stage_result", current_level_index, current_stage_index, stars, cleared_early)
	if hud and hud.has_method("show_stage_result"):
		hud.show_stage_result(stars, cleared_early)

# --- Defensive HUD helpers (safe against HUD not having caught up yet) ----

func _notify_timer_update() -> void:
	if hud and hud.has_method("update_timer"):
		hud.update_timer(_time_remaining)

func _notify(text: String, type: String = "info") -> void:
	if hud and "notification_area" in hud and hud.notification_area != null:
		hud.notification_area.push(text, type)

# --- Roster builders -------------------------------------------------------
# id scheme: l{level}_s{stage}_{descriptor}
# Lovey Dovey pairs are TWO Passenger resources/sprites, not seat_size=2 

func _make(id: String, p_name: String, overrides: Dictionary) -> Passenger:
	var p := Passenger.new()
	p.id = id
	p.passenger_name = p_name
	for key in overrides:
		if key in p:
			p.set(key, overrides[key])
	return p

func _make_regular(id: String, monologue: String) -> Passenger:
	return _make(id, "Regular Commuter", {"monologue_text": monologue})

# --- Level 1: Ang Unang Byahe (8-seater, 2x4) -------------------------------

func _build_l1_s1_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l1_s1_senior", "Senior", {"is_senior": true,
		"monologue_text": "May discount na sa Jollibee"}))
	list.append(_make("l1_s1_student", "Student", {"is_student": true, "is_introvert": true,
		"monologue_text": "Shy type"}))
	list.append(_make_regular("l1_s1_regular_1", "Papunta sa paroroonan."))
	list.append(_make_regular("l1_s1_regular_2", "Papunta sa paroroonan."))
	list.append(_make_regular("l1_s1_regular_3", "Papunta sa paroroonan."))
	return list

func _build_l1_s2_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l1_s2_pregnant", "Pregnant", {"is_pregnant": true,
		"monologue_text": "May gender reveal party mamaya."}))
	list.append(_make("l1_s2_balikbayan", "Balikbayan", {"is_balikbayan": true, "is_heavy_load": true,
		"monologue_text": "May dalang dalawang maleta."}))
	list.append(_make("l1_s2_near_stop", "Regular Commuter", {"alights_soon": true,
		"monologue_text": "Sa malapit lang."}))
	list.append(_make("l1_s2_jb_suarez", "JB Suarez", {"is_noisy": true,
		"monologue_text": "Nasigaw kapag may kamote."}))
	list.append(_make("l1_s2_market_goer", "Market Goer", {"is_heavy_load": true, "is_wet": true,
		"monologue_text": "Galing palengke."}))
	list.append(_make_regular("l1_s2_regular_2", "Papunta sa paroroonan."))
	return list

func _build_l1_s3_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l1_s3_holdaper", "Suspicious Passenger", {"is_holdaper": true,
		"monologue_text": "Suspicious."}))
	list.append(_make("l1_s3_employee", "Employee", {"is_employee": true,
		"monologue_text": "Maayos at plantsado ang uniform."}))
	list.append(_make("l1_s3_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Basang-basa ng pawis."}))
	list.append(_make_regular("l1_s3_regular_1", "Papunta sa paroroonan."))
	list.append(_make_regular("l1_s3_regular_2", "Papunta sa paroroonan."))
	return list

# --- Level 2: The Scent and Sound (10-seater, 2x5) --------------------------

func _build_l2_s1_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l2_s1_graveyard", "Graveyard-Shift Worker", {"is_graveyard_worker": true, "is_sleepy": true,
		"monologue_text": "Antok na."}))
	list.append(_make("l2_s1_jb_suarez", "JB Suarez", {"is_noisy": true,
		"monologue_text": "Nasigaw sa kamote."}))
	var lover_a := _make("l2_s1_lover_a", "Lovey Dovey A", {"is_companion": true, "companion_id": "l2_s1_lover_b",
		"monologue_text": "."})
	var lover_b := _make("l2_s1_lover_b", "Lovey Dovey B", {"is_companion": true, "companion_id": "l2_s1_lover_a",
		"monologue_text": "."})
	list.append(lover_a)
	list.append(lover_b)
	list.append(_make("l2_s1_student", "Student", {"is_student": true,
		"monologue_text": "Fresh na fresh, bagong ligo."}))
	list.append(_make("l2_s1_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Kakatakbo lang papuntang sakayan."}))
	list.append(_make("l2_s1_near_stop", "Regular Commuter", {"alights_soon": true,
		"monologue_text": "Malapit lang."}))
	return list

func _build_l2_s2_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l2_s2_senior", "Senior", {"is_senior": true,
		"monologue_text": "May apo na sa tuhod."}))
	list.append(_make("l2_s2_balikbayan", "Balikbayan", {"is_balikbayan": true, "is_heavy_load": true,
		"monologue_text": "Maraming dalang pasalubong."}))
	list.append(_make("l2_s2_parent_baby", "Parent + Baby", {"is_parent_baby": true,
		"monologue_text": "Dakilang ina."}))
	list.append(_make("l2_s2_employee", "Employee", {"is_employee": true,
		"monologue_text": "Amoy sauvage elixir."}))
	list.append(_make("l2_s2_wet", "Regular Commuter", {"is_wet": true,
		"monologue_text": "Nabasa sa ulan kanina."}))
	list.append(_make("l2_s2_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Asim kilig."}))
	list.append(_make("l2_s2_pwd", "PWD", {"is_pwd": true,
		"monologue_text": "Pauwi na galing trabaho."}))
	list.append(_make_regular("l2_s2_regular_2", "Papunta sa paroroonan."))
	return list

func _build_l2_s3_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l2_s3_drunk", "Drunk Man", {"is_drunk_man": true, "is_noisy": true,
		"monologue_text": "Tinamaain ng CLVB."}))
	list.append(_make("l2_s3_holdaper", "Suspicious Passenger", {"is_holdaper": true,
		"monologue_text": "Suspicious"}))
	list.append(_make("l2_s3_student", "Student", {"is_student": true,
		"monologue_text": "Kaka retouch lang."}))
	list.append(_make("l2_s3_wet", "Regular Commuter", {"is_wet": true,
		"monologue_text": "Nabasa ng ulan kanina."}))
	list.append(_make("l2_s3_parent_baby", "Parent + Baby", {"is_parent_baby": true,
		"monologue_text": "Dakilang ina."}))
	list.append(_make("l2_s3_white_lady", "White Lady", {"is_white_lady": true,
		"monologue_text": "..."}))
	list.append(_make_regular("l2_s3_regular_2", "Papunta sa paroroonan."))
	return list

# --- Level 3: Full House Logic (8-seater, 2x4, full capacity) ---------------

func _build_l3_s1_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l3_s1_pwd", "PWD", {"is_pwd": true,
		"monologue_text": "May saklay."}))
	list.append(_make("l3_s1_market_goer", "Market Goer", {"is_heavy_load": true, "is_wet": true,
		"monologue_text": "May dalang timba ng isda."}))
	var lover_a := _make("l3_s1_lover_a", "Lovey Dovey A", {"is_companion": true, "companion_id": "l3_s1_lover_b",
		"monologue_text": "HHWW (Holding Hands While Waiting)."})
	var lover_b := _make("l3_s1_lover_b", "Lovey Dovey B", {"is_companion": true, "companion_id": "l3_s1_lover_a",
		"monologue_text": "HHWW (Holding Hands While Waiting)."})
	list.append(lover_a)
	list.append(lover_b)
	list.append(_make("l3_s1_employee", "Employee", {"is_employee": true,
		"monologue_text": "Bagong ligo."}))
	list.append(_make("l3_s1_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Amoy araw."}))
	list.append(_make_regular("l3_s1_regular_1", "Papunta sa paroroonan."))
	list.append(_make_regular("l3_s1_regular_2", "Papunta sa paroroonan."))
	return list

func _build_l3_s2_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l3_s2_pregnant", "Pregnant", {"is_pregnant": true,
		"monologue_text": "7 months na siya (hindi lang halata)."}))
	list.append(_make("l3_s2_balikbayan", "Balikbayan", {"is_balikbayan": true, "is_heavy_load": true,
		"monologue_text": "May malaking bagahe."}))
	list.append(_make("l3_s2_student", "Student", {"is_student": true,
		"monologue_text": "Amoy bench atlantis."}))
	list.append(_make("l3_s2_jb_suarez", "JB Suarez", {"is_noisy": true,
		"monologue_text": "MAIIPIT KA NGA NI!"}))
	list.append(_make("l3_s2_graveyard", "Graveyard-Shift Worker", {"is_graveyard_worker": true, "is_sleepy": true,
		"monologue_text": "Wala pang tulog."}))
	list.append(_make("l3_s2_wet", "Regular Commuter", {"is_wet": true,
		"monologue_text": "Nabasa sa ulan kanina."}))
	list.append(_make_regular("l3_s2_regular_1", "Papunta sa paroroonan."))
	list.append(_make_regular("l3_s2_regular_2", "Papunta sa paroroonan."))
	return list


func _build_l3_s3_roster() -> Array[Passenger]:
	var list: Array[Passenger] = []
	list.append(_make("l3_s3_senior", "Senior", {"is_senior": true,
		"monologue_text": "Buhay na siya noong martial law."}))
	list.append(_make("l3_s3_drunk", "Drunk Man", {"is_drunk_man": true, "is_noisy": true,
		"monologue_text": "Magmamaoy ata."}))
	list.append(_make("l3_s3_parent_baby", "Parent + Baby", {"is_parent_baby": true,
		"monologue_text": "Karga ang baby."}))
	list.append(_make("l3_s3_employee", "Employee", {"is_employee": true,
		"monologue_text": "Umiiwas sa dugyot."}))
	list.append(_make("l3_s3_introvert", "Regular Commuter", {"is_introvert": true,
		"monologue_text": "Yes, ang sagot sa dine-in or takeout?"}))
	list.append(_make("l3_s3_sweaty", "Regular Commuter", {"is_sweaty": true,
		"monologue_text": "Pawis na pawis"}))
	list.append(_make("l3_s3_white_lady", "White Lady", {"is_white_lady": true,
		"monologue_text": "..."}))
	list.append(_make("l3_s3_holdaper", "Suspicious Passenger", {"is_holdaper": true,
		"monologue_text": "Masama ang tingin sa mga kwintas."}))
	return list
