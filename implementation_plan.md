# Implementation Plan: Systems Architect (Dev 1) Core Logic & Validation

This plan establishes the foundational data contract, grid structure, and rule validation engine for **Tabi-Tabi** (Deductive Reasoning Puzzle). These components serve as the back-end logic, which the UI and Interaction developers (Devs 2 and 3) will hook into.

## User Review Required

> [!NOTE]
> All systems will be implemented using pure GDScript scripts (`.gd` files), keeping the logic detached from visual scenes to enable clean testing and integration.

> [!IMPORTANT]
> Bulky passengers (size = 2) will occupy two adjacent indices in the row grid. The grid helper functions will handle mapping so that adjacency checks correctly bypass self-cells.

## Open Questions
No open questions at this stage. We have aligned on using **Option A (Fixed Grid Slots)** for the Jeepney seating (2 rows x 8 columns).

---

## Proposed Changes

### Core Logic Component
This component defines the base passenger data structure, the jeepney seating grid, and the validation engine.

#### [NEW] [passenger.gd](scripts/passenger.gd)
Create the custom Resource definition for passengers. Designers can instantiate this Resource in Godot to build passenger types.
* **Attributes**:
  * `id`: String (unique identifier, e.g. "student_sleepy")
  * `passenger_name`: String (e.g. "Juan")
  * `seat_size_passenger`: int = 1 (Standard = 1, Bulky = 2)
  * `monologue_text`: String (clues)
  * `anger_meter_max`: float = 60.0 (seconds before they walk away)
  * **Flags**:
    * `is_senior`: bool
    * `is_pwd`: bool
    * `is_pregnant`: bool
    * `is_student`: bool
    * `is_wet`: bool (carrying wet market goods or umbrella)
    * `is_asleep`: bool
    * `is_loud`: bool
    * `destination_stop`: int = 1 (1 is early, 5 is late)
    * `companion_id`: String = "" (companion they must sit with or face)

#### [NEW] [jeepney_grid.gd](scripts/jeepney_grid.gd)
Create the seating grid representation (2 rows x 8 columns).
* **Indices representation**:
  * Row `0`: Top Bench
  * Row `1`: Bottom Bench
  * Col `0`: Rear/Entrance (closest to exit)
  * Col `7`: Front/Driver (closest to driver)
* **Key Functions**:
  * `can_place_passenger(passenger: Passenger, row: int, col: int) -> bool`
  * `place_passenger(passenger: Passenger, row: int, col: int) -> bool`
  * `remove_passenger(passenger: Passenger) -> void`
  * `get_passenger_at(row: int, col: int) -> Passenger`
  * `get_unique_passengers() -> Array[Passenger]`
  * `get_adjacent_neighbors(passenger: Passenger) -> Array[Passenger]`

#### [NEW] [rule_validator.gd](scripts/rule_validator.gd)
Create the central validation engine to assess constraints and happiness.
* **Checks**:
  * **Tagabot (Fare Passer) Rule**: Ensure row indices `7` do not contain sleeping, bulky-baggage, or baby-holding passengers.
  * **Accessibility Rule**: Priority passengers (`is_senior`, `is_pwd`, `is_pregnant`) must be seated closer to index `0` (rear) than non-priority passengers in the same row.
  * **Palengke Conflict**: Wet passengers (`is_wet`) cannot sit directly next to employees.
  * **Magkasama (Companion) Rule**: Companions must sit adjacent in the same row or directly face each other in the same column across rows.
  * **Uso Umuwi Rule**: Passenger with early exit (`destination_stop = 1`) cannot have any bulky passenger (`size = 2`) seated closer to the entrance (`col < passenger_col`) in their row.

#### [NEW] [test_runner.gd](scripts/test_runner.gd)
A standalone test script that sets up passenger configurations, places them on a `JeepneyGrid`, and runs assertions on `RuleValidator` to ensure all mathematical/logic checks are correct.

---

## Verification Plan

### Automated Tests
Run the standalone test runner script from the command line:
* Command: `godot --headless -s scripts/test_runner.gd` (or via Godot editor using "Run Script" if headless is not in path).

### Manual Verification
* Validate script syntax in Godot Editor to ensure zero compile-time errors.
