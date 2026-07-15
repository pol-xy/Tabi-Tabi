class_name RuleValidator
extends RefCounted

# Validates the entire jeepney grid and returns a dictionary report of the status.
# Report structure:
# {
#     "is_valid": bool,
#     "violated_rules": Array[String],
#     "passenger_status": Dictionary (key: String, value: {"is_happy": bool, "complaints": Array[String]})
# }
static func validate(grid: JeepneyGrid) -> Dictionary:
	var report = {
		"is_valid": true,
		"violated_rules": [],
		"passenger_status": {},
		"passenger_status_keys": {}
	}
	
	var seated_passengers = grid.get_unique_passengers()
	
	# Initialize passenger status
	for p in seated_passengers:
		var status_key = _get_status_key(report, p)
		report.passenger_status[status_key] = {
			"is_happy": true,
			"complaints": []
		}
		
	# Run validation checks
	_check_tagabot_rule(grid, report)
	_check_accessibility_rule(grid, report)
	_check_palengke_conflict(grid, report)
	_check_introvert_conflict(grid, report)
	_check_magkasama_rule(grid, report)
	_check_uso_umuwi_rule(grid, report)
	_check_new_character_rules(grid, report)
	
	# Evaluate final overall validity
	for p_id in report.passenger_status:
		if not report.passenger_status[p_id]["is_happy"]:
			report.is_valid = false
			
	report.erase("passenger_status_keys")
			
	return report

# 1. The Tagabot (Fare Passer) Rule
# Seat at index 7 (next to driver) must 
# not have sleeping, bulky, PWD, senior, or pregnant passengers.
static func _check_tagabot_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	for r in range(grid.row_count):
		var p = grid.get_passenger_at(r, grid.col_count - 1)
		if p != null:
			var cannot_pass_fare = (
				p.is_sleepy or 
				p.seat_size_passenger > 1 or 
				p.is_heavy_load or 
				p.is_pwd or 
				p.is_senior or 
				p.is_pregnant
			)
			if cannot_pass_fare:
				_mark_unhappy(report, p, "tagabot", "Hindi ako makakapag-abot ng bayad dito (may condition/tulog/bulky).")

# 2. The Accessibility Rule
# Seniors, PWDs, Pregnant must sit closer to the entrance 
#(lower index) than regular passengers in the same row.

static func _check_accessibility_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	for r in range(grid.row_count):
		# Collect all unique passengers in this row and their leftmost columns
		var passengers_in_row = []
		var min_cols = {}
		
		for c in range(grid.col_count):
			var p = grid.get_passenger_at(r, c)
			if p != null and not passengers_in_row.has(p):
				passengers_in_row.append(p)
				min_cols[p.id] = c
				
		# Compare columns of priority vs non-priority
		for p1 in passengers_in_row:
			var p1_is_priority = p1.is_senior or p1.is_pwd or p1.is_pregnant
			if p1_is_priority:
				for p2 in passengers_in_row:
					var p2_is_priority = p2.is_senior or p2.is_pwd or p2.is_pregnant
					if not p2_is_priority:
						# If non-priority (p2) is closer to the entrance (lower index) than priority (p1)
						if min_cols[p2.id] < min_cols[p1.id]:
							_mark_unhappy(report, p1, "accessibility", "Dapat mas malapit ako sa sakayan/entrance (rear) kaysa sa mga regular.")
							_mark_unhappy(report, p2, "accessibility", "Nakaharang ako sa priority seat area ng mga nangangailangan.")

# 3. Palengke Conflict (is_wet next to is_employee)
static func _check_palengke_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_wet or p.is_sweaty:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_employee:
					var reason_self = "Basa ako" if p.is_wet else "Pawisan ako"
					var reason_neighbor = "Basa" if p.is_wet else "Pawisan at malagkit"
					_mark_unhappy(report, p.id, "palengke", "%s, baka madumihan ko ang katabi kong office worker." % reason_self)
					_mark_unhappy(report, n.id, "palengke", "%s yung katabi ko, madudumihan ang uniporme ko!" % reason_neighbor)

# 4. Introvert Conflict (is_introvert next to is_loud)
static func _check_introvert_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_introvert:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_noisy:
					_mark_unhappy(report, p.id, "introvert_conflict", "Masyadong maingay ang katabi ko, gusto ko ng katahimikan.")
					_mark_unhappy(report, n.id, "introvert_conflict", "Maingay ako, mukhang naiirita ang katabi ko.")

# 5. Magkasama (Companion) Rule
# Companions must be side-by-side or directly facing.
static func _check_magkasama_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.companion_id != "":
			# Find companion
			var companion = null
			for other in passengers:
				if other.id == p.companion_id:
					companion = other
					break
					
			if companion == null:
				_mark_unhappy(report, p, "magkasama", "Nahiwalay ako sa kasama ko na hindi nakasakay.")
				continue
				
			var slots_p = grid.get_occupied_slots(p)
			var slots_c = grid.get_occupied_slots(companion)
			
			if slots_p.is_empty() or slots_c.is_empty():
				_mark_unhappy(report, p, "magkasama", "Nahiwalay ako sa aking kasama.")
				continue
				
			var row_p = slots_p[0].x
			var row_c = slots_c[0].x
			
			var cols_p = slots_p.map(func(slot): return slot.y)
			var cols_c = slots_c.map(func(slot): return slot.y)
			
			# Case A: Same row (must be adjacent side-by-side)
			if row_p == row_c:
				var min_p = cols_p[0]
				var max_p = cols_p[cols_p.size() - 1]
				var min_c = cols_c[0]
				var max_c = cols_c[cols_c.size() - 1]
				
				var is_adjacent = (max_p + 1 == min_c) or (max_c + 1 == min_p)
				if not is_adjacent:
					_mark_unhappy(report, p, "magkasama", "Dapat katabi ko ang kasama ko sa upuan.")
					_mark_unhappy(report, companion, "magkasama", "Dapat katabi ko ang kasama ko sa upuan.")
					
			# Case B: Opposite rows (must face each other directly by sharing column index)
			else:
				var overlaps = false
				for col in cols_p:
					if cols_c.has(col):
						overlaps = true
						break
				if not overlaps:
					_mark_unhappy(report, p, "magkasama", "Dapat kaharap ko ang kasama ko sa kabilang bench.")
					_mark_unhappy(report, companion, "magkasama", "Dapat kaharap ko ang kasama ko sa kabilang bench.")

# 6. The Uso Umuwi Rule (destination_stop = 1 cannot have a bulky passenger closer to the exit than them)
static func _check_uso_umuwi_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.destination_stop == 1:
			var slots = grid.get_occupied_slots(p)
			if slots.is_empty():
				continue
			var row = slots[0].x
			var min_col = slots[0].y
			
			# Check all columns between entrance (0) and passenger's position
			for c in range(min_col):
				var blocker = grid.get_passenger_at(row, c)
				if blocker != null and (blocker.seat_size_passenger > 1 or blocker.is_heavy_load):
					_mark_unhappy(report, p.id, "uso_umuwi", "Mahihirapan akong bumaba dahil nakaharang ang bulky passenger sa exit.")
					break

# 7. Holdaper and Graveyard Worker custom rules
static func _check_new_character_rules(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		# Holdaper: must be seated at the front (index grid.col_count - 1)
		if p.is_holdaper:
			var slots = grid.get_occupied_slots(p)
			if not slots.is_empty():
				var col = slots[slots.size() - 1].y
				if col != grid.col_count - 1:
					_mark_unhappy(report, p.id, "holdaper_panic", "Gusto ko sa tabi ng driver sasakay!")
					# Nearby passengers take a happiness hit
					var neighbors = grid.get_adjacent_neighbors(p)
					for n in neighbors:
						_mark_unhappy(report, n.id, "holdaper_panic", "Mukhang holdaper itong katabi ko, natatakot ako!")
		
		# Graveyard-Shift Worker: Sleepy-heavy, wants a quiet corner
		if p.is_graveyard_worker:
			var slots = grid.get_occupied_slots(p)
			if not slots.is_empty():
				var min_col = slots[0].y
				var max_col = slots[slots.size() - 1].y
				var is_in_corner = (min_col == 0 or max_col == grid.col_count - 1)
				if not is_in_corner:
					_mark_unhappy(report, p.id, "graveyard_worker", "Gusto ko sana sa dulo/sulok para makapahinga.")
				
				# Cannot be next to a noisy passenger
				var neighbors = grid.get_adjacent_neighbors(p)
				for n in neighbors:
					if n.is_noisy:
						_mark_unhappy(report, p.id, "graveyard_worker", "Masyadong maingay ang katabi ko, hindi ako makatulog.")

# Helper to mark passenger unhappy and record complaint
static func _mark_unhappy(report: Dictionary, passenger: Passenger, rule_name: String, complaint: String) -> void:
	var p_key = _get_status_key(report, passenger)
	if report.passenger_status.has(p_key):
		report.passenger_status[p_key]["is_happy"] = false
		if not report.passenger_status[p_key]["complaints"].has(complaint):
			report.passenger_status[p_key]["complaints"].append(complaint)
	
	if not report.violated_rules.has(rule_name):
		report.violated_rules.append(rule_name)

static func _get_status_key(report: Dictionary, passenger: Passenger) -> String:
	var instance_key = str(passenger.get_instance_id())
	if report.passenger_status_keys.has(instance_key):
		return report.passenger_status_keys[instance_key]
	
	var status_key = passenger.id
	if status_key == "" or report.passenger_status.has(status_key):
		status_key = "__passenger_%s" % instance_key
	
	report.passenger_status_keys[instance_key] = status_key
	return status_key
