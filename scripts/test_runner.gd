extends SceneTree

func _init() -> void:
	print("\n==============================================")
	print("    RUNNING TABI-TABI CORE LOGIC TESTS")
	print("==============================================\n")
	
	var success = run_tests()
	
	if success:
		print("\n==============================================")
		print("       ALL TESTS PASSED SUCCESSFULLY! ✅")
		print("==============================================\n")
	else:
		print("\n==============================================")
		print("       TEST EXECUTION FAILED! ❌")
		print("==============================================\n")
	
	quit(0 if success else 1)

func run_tests() -> bool:
	var overall_pass = true
	
	overall_pass = test_passenger_grid_placement() and overall_pass
	overall_pass = test_tagabot_rule() and overall_pass
	overall_pass = test_accessibility_rule() and overall_pass
	overall_pass = test_palengke_conflict() and overall_pass
	overall_pass = test_introvert_conflict() and overall_pass
	overall_pass = test_magkasama_rule() and overall_pass
	overall_pass = test_new_proposed_traits_and_characters() and overall_pass
	
	return overall_pass

func assert_true(condition: bool, message: String) -> bool:
	if condition:
		print("  [PASS] %s" % message)
		return true
	else:
		print("  [FAIL] %s" % message)
		return false

func test_passenger_grid_placement() -> bool:
	print("--- Running Test: Grid Placement ---")
	var grid = JeepneyGrid.new()
	
	var standard = Passenger.new()
	standard.id = "std_1"
	standard.seat_size_passenger = 1
	
	var bulky = Passenger.new()
	bulky.id = "blk_1"
	bulky.seat_size_passenger = 2
	
	var test_ok = true
	test_ok = assert_true(grid.can_place_passenger(standard, 0, 0), "Standard passenger fits at 0,0") and test_ok
	test_ok = assert_true(grid.place_passenger(standard, 0, 0), "Standard passenger successfully placed at 0,0") and test_ok
	
	test_ok = assert_true(grid.get_passenger_at(0, 0) == standard, "Retrieved standard passenger from 0,0") and test_ok
	
	# Bulky passenger checks
	test_ok = assert_true(grid.can_place_passenger(bulky, 0, 1), "Bulky passenger fits at 0,1") and test_ok
	test_ok = assert_true(grid.place_passenger(bulky, 0, 1), "Bulky passenger successfully placed at 0,1") and test_ok
	test_ok = assert_true(grid.get_passenger_at(0, 1) == bulky, "Retrieved bulky passenger from 0,1") and test_ok
	test_ok = assert_true(grid.get_passenger_at(0, 2) == bulky, "Retrieved bulky passenger from 0,2 (occupies index + 1)") and test_ok
	
	# Collision check
	var collider = Passenger.new()
	collider.id = "std_2"
	collider.seat_size_passenger = 1
	test_ok = assert_true(not grid.can_place_passenger(collider, 0, 2), "Cannot place passenger in occupied cell 0,2") and test_ok
	
	# Clean up
	grid.remove_passenger(standard)
	test_ok = assert_true(grid.get_passenger_at(0, 0) == null, "Passenger std_1 removed successfully") and test_ok
	
	return test_ok

func test_tagabot_rule() -> bool:
	print("--- Running Test: Tagabot (Fare Passer) Rule ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	# Active regular passenger should be fine behind driver (index 4)
	var active_p = Passenger.new()
	active_p.id = "active_worker"
	active_p.is_employee = true
	grid.place_passenger(active_p, 0, 4)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Active passenger behind driver is valid") and test_ok
	
	# Sleeping passenger behind driver should violate rule
	grid.remove_passenger(active_p)
	var sleeper = Passenger.new()
	sleeper.id = "sleepy_student"
	sleeper.is_sleepy = true
	grid.place_passenger(sleeper, 0, 4)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Sleeping passenger behind driver violates Tagabot rule") and test_ok
	test_ok = assert_true(report.violated_rules.has("tagabot"), "Tagabot rule flagged in report") and test_ok
	
	# PWD passenger behind driver should violate rule
	var pwd_p = Passenger.new()
	pwd_p.id = "pwd_guy"
	pwd_p.is_pwd = true
	grid.place_passenger(pwd_p, 1, 4)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.passenger_status.has("pwd_guy") and not report.passenger_status["pwd_guy"]["is_happy"], "PWD passenger is unhappy behind driver") and test_ok
	
	# Near-stop passenger behind driver should violate rule
	grid.clear_grid()
	var early_off = Passenger.new()
	early_off.id = "atat_bumaba"
	early_off.alights_soon = true
	grid.place_passenger(early_off, 0, 4)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Near-stop passenger behind driver violates Tagabot rule") and test_ok
	
	return test_ok

func test_accessibility_rule() -> bool:
	print("--- Running Test: Accessibility Rule ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	# Tier 1 (Senior) must sit exactly at index 0 (Tapat ng Pinto)
	var senior = Passenger.new()
	senior.id = "lola"
	senior.is_senior = true
	
	grid.place_passenger(senior, 0, 0)
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Senior at Tapat ng Pinto is valid") and test_ok
	
	# Place Senior at index 1 - should violate Accessibility Tier 1
	grid.clear_grid()
	grid.place_passenger(senior, 0, 1)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Senior at index 1 violates Accessibility Tier 1") and test_ok
	
	# Tier 2 (Heavy Load / Balikbayan) can sit at index 1
	grid.clear_grid()
	var heavy = Passenger.new()
	heavy.id = "balikbayan"
	heavy.is_heavy_load = true
	
	grid.place_passenger(heavy, 0, 1)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Heavy load at index 1 is valid (Tier 2)") and test_ok
	
	# Place heavy load at index 2 - should violate
	grid.clear_grid()
	grid.place_passenger(heavy, 0, 2)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Heavy load at index 2 violates Accessibility Tier 2") and test_ok
	test_ok = assert_true(report.violated_rules.has("accessibility"), "Accessibility rule flagged for heavy load") and test_ok
	
	return test_ok

func test_palengke_conflict() -> bool:
	print("--- Running Test: Hygiene (Maarte) Conflict ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	var wet_p = Passenger.new()
	wet_p.id = "wet_guy"
	wet_p.is_wet = true
	
	var student = Passenger.new()
	student.id = "student_uniform"
	student.is_student = true
	
	# Wet and student side-by-side
	grid.place_passenger(wet_p, 0, 2)
	grid.place_passenger(student, 0, 3)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Wet passenger next to student violates Hygiene Conflict") and test_ok
	test_ok = assert_true(report.violated_rules.has("palengke"), "Hygiene (palengke) rule flagged") and test_ok
	
	# Sweaty and employee side-by-side
	grid.clear_grid()
	var sweaty = Passenger.new()
	sweaty.id = "sweaty_guy"
	sweaty.is_sweaty = true
	
	var employee = Passenger.new()
	employee.id = "office_worker"
	employee.is_employee = true
	
	grid.place_passenger(sweaty, 0, 2)
	grid.place_passenger(employee, 0, 3)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Sweaty passenger next to employee violates Hygiene Conflict") and test_ok
	
	# PDA / Lovey Dovey (size 2) next to employee
	grid.clear_grid()
	var pair = Passenger.new()
	pair.id = "lovey_dovey"
	pair.seat_size_passenger = 2
	
	grid.place_passenger(pair, 0, 1) # occupies 1-2
	grid.place_passenger(employee, 0, 3) # sits next to them
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "PDA/Lovey Dovey next to employee is fine now") and test_ok
	
	return test_ok

func test_introvert_conflict() -> bool:
	print("--- Running Test: Introvert Conflict ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	var introvert = Passenger.new()
	introvert.id = "introvert_girl"
	introvert.is_introvert = true
	
	var loud_p = Passenger.new()
	loud_p.id = "maingay_kid"
	loud_p.is_noisy = true
	
	# Adjacent
	grid.place_passenger(introvert, 0, 2)
	grid.place_passenger(loud_p, 0, 3)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Introvert next to loud passenger violates Introvert Conflict") and test_ok
	test_ok = assert_true(report.violated_rules.has("introvert_conflict"), "Introvert conflict flagged") and test_ok
	
	# Separate
	grid.place_passenger(loud_p, 0, 4)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Separated introvert and loud passenger are valid") and test_ok
	
	return test_ok

func test_magkasama_rule() -> bool:
	print("--- Running Test: Magkasama (Companion) Rule ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	var partner_a = Passenger.new()
	partner_a.id = "couple_a"
	partner_a.companion_id = "couple_b"
	
	var partner_b = Passenger.new()
	partner_b.id = "couple_b"
	partner_b.companion_id = "couple_a"
	
	# Test 1: Separated (Only A is on the grid)
	grid.place_passenger(partner_a, 0, 2)
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Companion missing from grid is invalid") and test_ok
	
	# Test 2: Placed side-by-side (valid)
	grid.place_passenger(partner_b, 0, 3)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Companions seated side-by-side are valid") and test_ok
	
	# Test 3: Placed opposite / facing each other (valid)
	grid.place_passenger(partner_b, 1, 2) # Row 1 Col 2 (directly facing Row 0 Col 2)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Companions seated directly opposite are valid") and test_ok
	
	# Test 4: Seated apart (invalid)
	grid.place_passenger(partner_b, 1, 4)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Companions seated apart are invalid") and test_ok
	test_ok = assert_true(report.violated_rules.has("magkasama"), "Magkasama rule flagged") and test_ok
	
	return test_ok

func test_new_proposed_traits_and_characters() -> bool:
	print("--- Running Test: New Proposed Traits & Characters ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	# Test 1: Sweaty passenger next to employee (should violate Palengke rule)
	var sweaty = Passenger.new()
	sweaty.id = "sweaty_guy"
	sweaty.is_sweaty = true
	
	var worker = Passenger.new()
	worker.id = "office_worker"
	worker.is_employee = true
	
	grid.place_passenger(sweaty, 0, 1)
	grid.place_passenger(worker, 0, 2)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Sweaty next to employee violates conflict") and test_ok
	test_ok = assert_true(report.violated_rules.has("palengke"), "Sweaty conflict flagged under palengke rule") and test_ok
	
	# Test 2: Holdaper positioning (must sit next to driver, index 0)
	grid.clear_grid()
	var holdaper = Passenger.new()
	holdaper.id = "holdaper"
	holdaper.is_holdaper = true
	
	# Placing holdaper in middle (col 2)
	grid.place_passenger(holdaper, 0, 2)
	grid.place_passenger(worker, 0, 3) # worker sits next to holdaper
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Holdaper in middle is invalid") and test_ok
	test_ok = assert_true(report.violated_rules.has("holdaper_panic"), "Holdaper panic flagged") and test_ok
	test_ok = assert_true(report.passenger_status.has("office_worker") and not report.passenger_status["office_worker"]["is_happy"], "Worker is unhappy next to misplaced holdaper") and test_ok
	
	# Placing holdaper behind driver (col 4) - should be fine
	grid.clear_grid()
	grid.place_passenger(holdaper, 0, 4)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Holdaper next to driver (index 4) is valid") and test_ok
	
	# Test 3: Graveyard shift worker wants quiet corner
	grid.clear_grid()
	var graveyard = Passenger.new()
	graveyard.id = "graveyard_shift"
	graveyard.is_graveyard_worker = true
	
	# Sits in middle (invalid corner)
	grid.place_passenger(graveyard, 0, 2)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Graveyard worker in middle is invalid") and test_ok
	
	# Sits in corner (col 0)
	grid.clear_grid()
	grid.place_passenger(graveyard, 0, 0)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Graveyard worker in corner is valid") and test_ok
	
	# Test 4: Drunk Man wide radius (<= 2 seats)
	grid.clear_grid()
	var drunk = Passenger.new()
	drunk.id = "drunk_man"
	drunk.is_drunk_man = true
	
	var introvert = Passenger.new()
	introvert.id = "introvert_student"
	introvert.is_introvert = true
	
	grid.place_passenger(drunk, 0, 0)
	grid.place_passenger(introvert, 0, 2) # Distance = 2. Should violate!
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Introvert within 2 seats of Drunk Man violates rule") and test_ok
	test_ok = assert_true(report.violated_rules.has("introvert_conflict"), "Introvert conflict flagged with Drunk Man") and test_ok
	
	# Place introvert at col 3 (distance = 3). Should be fine
	grid.remove_passenger(introvert)
	grid.place_passenger(introvert, 0, 3)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Introvert 3 seats away from Drunk Man is valid") and test_ok
	
	return test_ok
