class_name Passenger
extends Resource

# Attributes of our passenger
@export var id: String = ""
@export var passenger_name: String = ""
@export var seat_size_passenger: int = 1 # 1 = standard, 2 = bulky 
@export_multiline var monologue_text: String = ""
@export var anger_meter_max: float = 60.0

# Priority / accessibility flags / status
@export var is_senior: bool = false
@export var is_pwd: bool = false
@export var is_pregnant: bool = false
@export var is_student: bool = false
@export var is_employee: bool = false
@export var is_badjao: bool = false   # Non-passenger (e.g. envelope distributor)
@export var is_companion: bool = false # Person who must sit with another
@export var is_parent_baby: bool = false # Parent holding a baby
@export var is_balikbayan: bool = false   # OFW passenger (carries large boxes/heavy load)
@export var is_drunk_man: bool = false    # Drunk man (noisy with a wide radius)

# Behavioral / state flags
@export var is_wet: bool = false       # Carrying wet fish or wet umbrella
@export var is_sleepy: bool = false    # Sleepy passenger
@export var is_noisy: bool = false     # Loud/noisy passenger
@export var is_introvert: bool = false # Dislikes noisy neighbors
@export var is_sweaty: bool = false    # Sweaty passenger
@export var is_heavy_load: bool = false # Carrying large boxes / heavy load
@export var is_holdaper: bool = false  # Night holdaper passenger
@export var is_graveyard_worker: bool = false # Graveyard shift worker
@export var is_white_lady: bool = false # White lady passenger (fast anger drain)
@export var alights_soon: bool = false    # Passenger alighting soon (wants to be close to door)

# Trip info
@export var destination_stop: int = 1  # Stop number when they alight
@export var companion_id: String = ""  # ID of companion they want to sit with or face
