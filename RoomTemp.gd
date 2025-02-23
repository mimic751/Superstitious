extends Area3D

### 🔹 Adjustable Temperature Settings
@export var base_temperature: float = 20.0  # Normal room temperature
@export var min_temperature: float = -10.0  # Minimum temperature allowed
@export var decay_rate: float = 0.5  # How fast the temperature returns to normal
@export var max_cold_spots: int = 5  # How many cold spots can exist before removing old ones
@export var temp_drop_per_ghost: float = 5.0 # How much temp drops when a ghost enters

### 🔹 Internal Variables
var current_temperature: float
var ghosts_inside: int = 0  # Track number of ghosts in this area
var cold_spots: Array = []  # Stores positions of recent ghost interactions

### 🔹 Cold Spot Structure
class ColdSpot:
	var position: Vector3
	var intensity: float
	var duration: float

	func _init(pos, intensity, duration):
		self.position = pos
		self.intensity = intensity
		self.duration = duration

func _ready():
	current_temperature = base_temperature  # Start at normal temperature
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

### 🔥 When a ghost enters the area, reduce temperature
func _on_body_entered(body):
	if body is CharacterBody3D and body.name.begins_with("Ghost_"):
		ghosts_inside += 1
		print("👻 Ghost entered! Total ghosts inside:", ghosts_inside)

### ❄️ When a ghost exits, restore temperature gradually
func _on_body_exited(body):
	if body is CharacterBody3D and body.name.begins_with("Ghost_"):
		ghosts_inside = max(ghosts_inside - 1, 0)
		print("👻 Ghost left. Remaining ghosts inside:", ghosts_inside)

### 🔄 Gradual Temperature Changes
func _physics_process(delta):
	if ghosts_inside > 0:
		# Drop temperature based on how many ghosts are inside
		var target_temp = base_temperature - (ghosts_inside * temp_drop_per_ghost)
		target_temp = max(target_temp, min_temperature)  # Ensure it doesn’t go below limit
		current_temperature = lerp(current_temperature, target_temp, delta * 2.0)
	
	else:
		# If no ghosts are inside, slowly warm back up
		current_temperature = lerp(current_temperature, base_temperature, decay_rate * delta)

	# Process cold spots
	process_cold_spots(delta)

### 🔹 Leaves a cold spot when a ghost interacts in the zone
func leave_cold_spot(pos, intensity, duration):
	if cold_spots.size() >= max_cold_spots:
		cold_spots.pop_front()  # Remove oldest cold spot

	cold_spots.append(ColdSpot.new(pos, intensity, duration))

### 🧊 Cold spots fade over time
func process_cold_spots(delta):
	for spot in cold_spots:
		spot.duration -= delta
		if spot.duration <= 0:
			cold_spots.erase(spot)

	# Apply cold effect based on active cold spots
	for spot in cold_spots:
		var dist = global_transform.origin.distance_to(spot.position)
		if dist < 3.0:  # If we're near a cold spot
			var cold_effect = clamp(spot.intensity * (3.0 - dist), 0, base_temperature - min_temperature)
			current_temperature = lerp(current_temperature, current_temperature - cold_effect, delta * 2.0)
