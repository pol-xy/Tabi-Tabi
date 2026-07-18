class_name RuleValidator
extends RefCounted

# Validates the entire jeepney grid,returns a dictionary report of the status
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
	_check_hygiene_conflict(grid, report)
	_check_introvert_conflict(grid, report)
	_check_magkasama_rule(grid, report)
	_check_new_character_rules(grid, report)
	
	# Evaluate final overall validity
	for p_id in report.passenger_status:
		if not report.passenger_status[p_id]["is_happy"]:
			report.is_valid = false
			
	report.erase("passenger_status_keys")
			
	return report

# --- 1. The Tagabot (Fare Passer) Rule
# Seat next to driver (highest index) must not have sleeping,
# bulky, PWD, senior, pregnant, or alights soon ---

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
				p.is_pregnant or
				p.is_parent_baby or
				p.alights_soon
			)
			if cannot_pass_fare:
				_mark_unhappy(report, p, "tagabot", "Hindi ako makakapag-abot ng bayad dito (may condition/tulog/bulky/bababa na).")

# --- 2. The Accessibility Rule
# Tier 1 (Seniors, PWDs, Pregnant) must sit at edge/idx 0
# Tier 2 (Heavy Loads) must sit near the door/idx 0 or 1 ---

static func _check_accessibility_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		var is_tier1 = p.is_senior or p.is_pwd or p.is_pregnant
		if is_tier1:
			var slots = grid.get_occupied_slots(p)
			var at_edge = false
			for slot in slots:
				if slot.y == 0:
					at_edge = true
					break
			if not at_edge:
				_mark_unhappy(report, p, "accessibility", "Dapat nasa Tapat ng Pinto (rear entrance, index 0) ako nakaupo.")
		
		elif p.is_heavy_load:
			var slots = grid.get_occupied_slots(p)
			var near_door = false
			for slot in slots:
				if slot.y == 0 or slot.y == 1:
					near_door = true
					break
			if not near_door:
				_mark_unhappy(report, p, "accessibility", "Dapat malapit ako sa exit (index 0 or 1) dahil may dala akong mabigat.")

# --- 3. Hygiene/Palengke Conflict 
# (is_wet or is_sweaty next to is_employee or is_student) ---

static func _check_hygiene_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_wet or p.is_sweaty:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_employee or n.is_student:
					var reason_self = "Basa ako" if p.is_wet else "Pawisan ako"
					var reason_neighbor = "Basa" if p.is_wet else "Pawisan at malagkit"
					var role_name = "office worker" if n.is_employee else "estudyante"
					_mark_unhappy(report, p, "palengke", "%s, baka madumihan ko ang katabi kong %s." % [reason_self, role_name])
					_mark_unhappy(report, n, "palengke", "%s yung katabi ko, madudumihan ang uniporme ko!" % reason_neighbor)

# --- 4. Introvert Conflict 
# (is_introvert next to is_noisy) ---

static func _check_introvert_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_introvert:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_noisy:
					_mark_unhappy(report, p, "introvert_conflict", "Masyadong maingay ang katabi ko, gusto ko ng katahimikan.")
					_mark_unhappy(report, n, "introvert_conflict", "Maingay ako, mukhang naiirita ang katabi ko.")
			
			# Check Drunk Man within 2 seats in any direction
			for other in passengers:
				if other.is_drunk_man:
					var slots_o = grid.get_occupied_slots(other)
					var slots_p = grid.get_occupied_slots(p)
					if not slots_o.is_empty() and not slots_p.is_empty():
						var col_o = slots_o[0].y
						var col_p = slots_p[0].y
						if abs(col_p - col_o) <= 2:
							_mark_unhappy(report, p, "introvert_conflict", "Masyadong maingay ang lasing na malapit sa akin.")
							_mark_unhappy(report, other, "introvert_conflict", "Maingay ako, mukhang naiirita ang mga katabi ko.")

# --- 5. Magkasama (Companion) Rule
# Companions must be side-by-side or directly facing eo ---

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


# --- 6. Holdaper and Graveyard Worker custom rules ---

static func _check_new_character_rules(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		# Holdaper: must be seated at the front (index grid.col_count - 1)
		if p.is_holdaper:
			var slots = grid.get_occupied_slots(p)
			if not slots.is_empty():
				var col = slots[slots.size() - 1].y
				if col != grid.col_count - 1:
					_mark_unhappy(report, p, "holdaper_panic", "Gusto ko sa tabi ng driver sasakay!")
					# Nearby passengers take a happiness hit
					var neighbors = grid.get_adjacent_neighbors(p)
					for n in neighbors:
						_mark_unhappy(report, n, "holdaper_panic", "Mukhang holdaper itong katabi ko, natatakot ako!")
		
		# Graveyard-Shift Worker: Sleepy-heavy, wants a quiet corner
		if p.is_graveyard_worker:
			var slots = grid.get_occupied_slots(p)
			if not slots.is_empty():
				var col = slots[0].y
				var is_corner = (col == 0 or col == grid.col_count - 1)
				if not is_corner:
					_mark_unhappy(report, p, "graveyard_worker", "Gusto ko sana sa dulo/sulok para makapahinga.")
				
				# Cannot be next to a noisy passenger
				var neighbors = grid.get_adjacent_neighbors(p)
				for n in neighbors:
					if n.is_noisy:
						_mark_unhappy(report, p, "graveyard_worker", "Masyadong maingay ang katabi ko, hindi ako makatulog.")
				
				# Cannot be within 2 seats of Drunk Man
				for other in passengers:
					if other.is_drunk_man:
						var slots_o = grid.get_occupied_slots(other)
						if not slots_o.is_empty():
							var col_o = slots_o[0].y
							if abs(col - col_o) <= 2:
								_mark_unhappy(report, p, "graveyard_worker", "Masyadong maingay ang lasing na malapit sa akin.")

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
