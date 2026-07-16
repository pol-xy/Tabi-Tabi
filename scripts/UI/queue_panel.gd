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
		
		# 1. Inject the data FIRST
		card.passenger_data = passenger
		
		# 2. Connect your signals
		card.card_selected.connect(_on_card_selected)
		
		# 3. Add it to the tree LAST. 
		# This safely triggers _ready() in passenger_card.gd AFTER the data is injected.
		card_row.add_child(card)
		
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

## Removes a passenger's card from queue bookkeeping WITHOUT freeing the
## node -- use this when the card has been reparented elsewhere (e.g. into
## a seat by seat_1.gd) rather than actually dismissed/removed from play.
## remove_passenger() above is for the latter case and frees the node.
func detach_passenger(passenger: Passenger) -> void:
	for i in _cards.size():
		if _cards[i].passenger_data == passenger:
			_cards.remove_at(i)
			break
	if _cards.size() > 0:
		_set_active(0)

func _set_active(index: int) -> void:
	for i in _cards.size():
		_cards[i].is_active = (i == index)

func _on_card_selected(passenger) -> void:
	emit_signal("passenger_focused", passenger)
