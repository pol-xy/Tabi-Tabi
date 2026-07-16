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
	overall_pass = test_uso_umuwi_rule() and overall_pass
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
	
	# Active regular passenger should be fine behind driver (index 0)
	var active_p = Passenger.new()
	active_p.id = "active_worker"
	active_p.is_employee = true
	grid.place_passenger(active_p, 0, 0)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Active passenger behind driver is valid") and test_ok
	
	# Sleeping passenger behind driver should violate rule
	grid.remove_passenger(active_p)
	var sleeper = Passenger.new()
	sleeper.id = "sleepy_student"
	sleeper.is_sleepy = true
	grid.place_passenger(sleeper, 0, 0)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Sleeping passenger behind driver violates Tagabot rule") and test_ok
	test_ok = assert_true(report.violated_rules.has("tagabot"), "Tagabot rule flagged in report") and test_ok
	
	# PWD passenger behind driver should violate rule
	var pwd_p = Passenger.new()
	pwd_p.id = "pwd_guy"
	pwd_p.is_pwd = true
	grid.place_passenger(pwd_p, 1, 0)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.passenger_status.has("pwd_guy") and not report.passenger_status["pwd_guy"]["is_happy"], "PWD passenger is unhappy behind driver") and test_ok
	
	return test_ok

func test_accessibility_rule() -> bool:
	print("--- Running Test: Accessibility Rule ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	# Priority (Senior) must sit at Tapat ng Pinto (index col_count - 1 = 4)
	var senior = Passenger.new()
	senior.id = "lola"
	senior.is_senior = true
	
	grid.place_passenger(senior, 0, 4)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Priority at Tapat ng Pinto is valid") and test_ok
	
	# Place priority passenger at non-exit column (index 2) - should violate
	grid.clear_grid()
	grid.place_passenger(senior, 0, 2)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Priority not at Tapat ng Pinto violates Accessibility rule") and test_ok
	test_ok = assert_true(report.violated_rules.has("accessibility"), "Accessibility rule flagged") and test_ok
	
	return test_ok

func test_palengke_conflict() -> bool:
	print("--- Running Test: Palengke Conflict ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	var wet_p = Passenger.new()
	wet_p.id = "palengke_vendor"
	wet_p.is_wet = true
	
	var employee = Passenger.new()
	employee.id = "office_worker"
	employee.is_employee = true
	
	# Wet and employee side-by-side
	grid.place_passenger(wet_p, 0, 2)
	grid.place_passenger(employee, 0, 3)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Wet passenger next to employee violates Palengke Conflict") and test_ok
	test_ok = assert_true(report.violated_rules.has("palengke"), "Palengke rule flagged") and test_ok
	
	# Separate them
	grid.place_passenger(employee, 0, 4)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Separated wet passenger and employee are valid") and test_ok
	
	# Bulky passenger adjacency should still be detected correctly (wet occupies 2 slots)
	grid.clear_grid()
	wet_p.seat_size_passenger = 2
	grid.place_passenger(wet_p, 0, 2) # occupies col 2-3
	grid.place_passenger(employee, 0, 4) # adjacent to wet passenger's right edge
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Bulky wet passenger next to employee violates Palengke Conflict") and test_ok
	test_ok = assert_true(report.violated_rules.has("palengke"), "Palengke rule flagged for bulky adjacency") and test_ok
	
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

func test_uso_umuwi_rule() -> bool:
	print("--- Running Test: Uso Umuwi Rule ---")
	var grid = JeepneyGrid.new()
	var test_ok = true
	
	var early_exit = Passenger.new()
	early_exit.id = "early_off_student"
	early_exit.destination_stop = 1
	
	var heavy = Passenger.new()
	heavy.id = "balikbayan_heavy"
	heavy.is_heavy_load = true
	
	# Early exit passenger placed at col 1, heavy passenger at col 2 (heavy is closer to exit/col 4 than early exit, which is fine)
	grid.place_passenger(early_exit, 0, 1)
	grid.place_passenger(heavy, 0, 2)
	
	var report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Heavy passenger seated behind early-exit passenger is valid") and test_ok
	
	# Swap: early exit to col 2, heavy to col 0 (heavy blocks the exit pathway to col 4)
	grid.remove_passenger(early_exit)
	grid.place_passenger(heavy, 0, 0)
	grid.place_passenger(early_exit, 0, 2)
	
	report = RuleValidator.validate(grid)
	test_ok = assert_true(not report.is_valid, "Early exit passenger blocked by heavy passenger closer to exit is invalid") and test_ok
	test_ok = assert_true(report.violated_rules.has("uso_umuwi"), "Uso Umuwi rule flagged") and test_ok
	
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
	
	# Placing holdaper behind driver (col 0) - should be fine
	grid.clear_grid()
	grid.place_passenger(holdaper, 0, 0)
	report = RuleValidator.validate(grid)
	test_ok = assert_true(report.is_valid, "Holdaper next to driver (index 0) is valid") and test_ok
	
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
