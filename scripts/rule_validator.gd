class_name RuleValidator
extends RefCounted

# Validates the entire jeepney grid and returns a dictionary report of the status.
# Report structure:
# {
#     "is_valid": bool,
#     "violated_rules": Array[String],
#     "passenger_status": Dictionary (key: String (passenger.id), value: {"is_happy": bool, "complaints": Array[String]})
# }
static func validate(grid: JeepneyGrid) -> Dictionary:
	var report = {
		"is_valid": true,
		"violated_rules": [],
		"passenger_status": {}
	}
	
	var seated_passengers = grid.get_unique_passengers()
	
	# Initialize passenger status
	for p in seated_passengers:
		report.passenger_status[p.id] = {
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
	
	# Evaluate final overall validity
	for p_id in report.passenger_status:
		if not report.passenger_status[p_id]["is_happy"]:
			report.is_valid = false
			
	return report

# 1. The Tagabot (Fare Passer) Rule
# Seat at index 7 (next to driver) must 
# not have sleeping, bulky, PWD, senior, or pregnant passengers.
static func _check_tagabot_rule(grid: JeepneyGrid, report: Dictionary) -> void:
	for r in range(grid.row_count):
		var p = grid.get_passenger_at(r, grid.col_count - 1)
		if p != null:
			var cannot_pass_fare = (
				p.is_asleep or 
				p.seat_size_passenger > 1 or 
				p.is_pwd or 
				p.is_senior or 
				p.is_pregnant
			)
			if cannot_pass_fare:
				_mark_unhappy(report, p.id, "tagabot", "Hindi ako makakapag-abot ng bayad dito (may condition/tulog/bulky).")

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
							_mark_unhappy(report, p1.id, "accessibility", "Dapat mas malapit ako sa sakayan/entrance (rear) kaysa sa mga regular.")
							_mark_unhappy(report, p2.id, "accessibility", "Nakaharang ako sa priority seat area ng mga nangangailangan.")

# 3. Palengke Conflict (is_wet next to is_employee)
static func _check_palengke_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_wet:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_employee:
					_mark_unhappy(report, p.id, "palengke", "Basa ako, baka madumihan ko ang katabi kong office worker.")
					_mark_unhappy(report, n.id, "palengke", "Basa yung katabi ko, madudumihan ang uniporme ko!")

# 4. Introvert Conflict (is_introvert next to is_loud)
static func _check_introvert_conflict(grid: JeepneyGrid, report: Dictionary) -> void:
	var passengers = grid.get_unique_passengers()
	for p in passengers:
		if p.is_introvert:
			var neighbors = grid.get_adjacent_neighbors(p)
			for n in neighbors:
				if n.is_loud:
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
				_mark_unhappy(report, p.id, "magkasama", "Nahiwalay ako sa kasama ko na hindi nakasakay.")
				continue
				
			var slots_p = grid.get_occupied_slots(p)
			var slots_c = grid.get_occupied_slots(companion)
			
			if slots_p.is_empty() or slots_c.is_empty():
				_mark_unhappy(report, p.id, "magkasama", "Nahiwalay ako sa aking kasama.")
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
					_mark_unhappy(report, p.id, "magkasama", "Dapat katabi ko ang kasama ko sa upuan.")
					_mark_unhappy(report, companion.id, "magkasama", "Dapat katabi ko ang kasama ko sa upuan.")
					
			# Case B: Opposite rows (must face each other directly by sharing column index)
			else:
				var overlaps = false
				for col in cols_p:
					if cols_c.has(col):
						overlaps = true
						break
				if not overlaps:
					_mark_unhappy(report, p.id, "magkasama", "Dapat kaharap ko ang kasama ko sa kabilang bench.")
					_mark_unhappy(report, companion.id, "magkasama", "Dapat kaharap ko ang kasama ko sa kabilang bench.")

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
				if blocker != null and blocker.seat_size_passenger > 1:
					_mark_unhappy(report, p.id, "uso_umuwi", "Mahihirapan akong bumaba dahil nakaharang ang bulky passenger sa exit.")
					break

# Helper to mark passenger unhappy and record complaint
static func _mark_unhappy(report: Dictionary, p_id: String, rule_name: String, complaint: String) -> void:
	if report.passenger_status.has(p_id):
		report.passenger_status[p_id]["is_happy"] = false
		if not report.passenger_status[p_id]["complaints"].has(complaint):
			report.passenger_status[p_id]["complaints"].append(complaint)
	
	if not report.violated_rules.has(rule_name):
		report.violated_rules.append(rule_name)
