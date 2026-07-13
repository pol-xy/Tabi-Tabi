extends ScrollContainer
## Scripts/UI/queue_panel.gd
## Horizontal strip of PassengerCard instances = the passengers waiting
## outside the jeepney. Owns which card is "active" (visually emphasized)
## and forwards selection upward so HUD can route it to the DialogueBubble.
##
## Dev 4 dependency: calls populate() when a stage/level loads with its
## passenger roster. Dev 2 dependency: calls advance() or remove_passenger()
## when a passenger is successfully seated or dismissed.

signal passenger_focused(passenger: Passenger)  ## HUD listens to this, forwards to DialogueBubble.

@export var passenger_card_scene: PackedScene

@onready var card_row: HBoxContainer = $CardRow

var _cards: Array[PassengerCard] = []  # in queue order

func _ready() -> void:
	pass

## Replaces the whole queue with a fresh passenger list for a new stage.
func populate(passengers: Array[Passenger]) -> void:
	clear()
	for passenger in passengers:
		var card = passenger_card_scene.instantiate()
		card_row.add_child(card)
		card.setup(passenger)
		card.card_selected.connect(_on_card_selected)
		_cards.append(card)
	if _cards.size() > 0:
		_set_active(0)

func clear() -> void:
	for card in _cards:
		card.queue_free()
	_cards.clear()

## Call when the front passenger is seated or dismissed — advances focus
## to the next passenger in line.
func advance() -> void:
	if _cards.is_empty():
		return
	var front = _cards.pop_front()
	front.queue_free()
	if _cards.size() > 0:
		_set_active(0)

## Call if a specific passenger (not necessarily the front) leaves the
## queue — relevant if the order-of-entry mechanic (UV Express) lets
## players pull someone other than the frontmost passenger.
func remove_passenger(passenger: Passenger) -> void:
	for i in _cards.size():
		if _cards[i].passenger_data == passenger:
			_cards[i].queue_free()
			_cards.remove_at(i)
			break
	if _cards.size() > 0:
		_set_active(0)

func is_empty() -> bool:
	return _cards.is_empty()

func _set_active(index: int) -> void:
	for i in _cards.size():
		_cards[i].is_active = (i == index)

func _on_card_selected(passenger) -> void:
	emit_signal("passenger_focused", passenger)
