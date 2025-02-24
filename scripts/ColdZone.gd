extends Area3D

# Adjustable Temperature Settings
@export var base_temperature: float = 20.0      # Temperature when no ghost is present
@export var min_temperature: float = -20.0      # Minimum temperature when ghost is present
@export var lowering_rate: float = .5      # Degrees per second drop when ghost is present
@export var raising_rate: float = 0.01            # Degrees per second rise when ghost is absent

# Internal Variables
var current_temperature: float

# Custom Signal
signal temperature_changed(new_temp)

func _ready():
	current_temperature = base_temperature
	print("Initial temperature:", current_temperature)
	emit_signal("temperature_changed", current_temperature)

func _physics_process(delta):
	var ghost_present = false
	for body in get_overlapping_bodies():
		if body.is_in_group("Ghosts"):
			ghost_present = true
			break

	var previous_temperature = current_temperature
	if ghost_present:
		# Lower the temperature gradually, but never below min_temperature.
		current_temperature = max(current_temperature - lowering_rate * delta, min_temperature)
	else:
		# Raise the temperature gradually, but never above base_temperature.
		current_temperature = min(current_temperature + raising_rate * delta, base_temperature)

	# Emit signal if temperature has changed noticeably.
	if abs(current_temperature - previous_temperature) > 0.00001:
		#print("Temperature update:", current_temperature)
		emit_signal("temperature_changed", current_temperature)
