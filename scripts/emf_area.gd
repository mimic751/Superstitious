extends Area3D

# EMF Zone Properties
@export var base_emf: float = 0.0    # Default room EMF when no ghost is present
@export var max_emf: float = 5.0      # Maximum EMF when ghost is present
@export var increase_rate: float = 0.01  # EMF increase per second when ghost is present
@export var decrease_rate: float = 0.1  # EMF decrease per second when ghost is absent

var current_emf: float

# Signal to notify EMF change
signal emf_changed(new_emf)

func _ready():
	current_emf = base_emf
	print("✅ [DEBUG] EMF Zone initialized:", current_emf)
	emit_signal("emf_changed", current_emf)

func _physics_process(delta):
	var ghost_present = false

	for body in get_overlapping_bodies():
		if body.is_in_group("Ghosts"):
			ghost_present = true
			break

	var previous_emf = current_emf

	if ghost_present:
		# Increase EMF gradually but never exceed max_emf
		current_emf = min(current_emf + increase_rate * delta, max_emf)
	else:
		# Decrease EMF gradually but never go below base_emf
		current_emf = max(current_emf - decrease_rate * delta, base_emf)

	if abs(current_emf - previous_emf) > 0.01:
		emit_signal("emf_changed", current_emf)

func get_emf_strength() -> float:
	return current_emf
