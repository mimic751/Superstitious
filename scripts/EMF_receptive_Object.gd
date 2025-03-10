extends RigidBody3D

@export var base_emf: float = 0.0  # Default EMF when inactive
@export var decay_rate: float = 0.2  # Speed at which EMF fades
var current_emf: float = 0.0  # Current EMF strength

func _ready():
	add_to_group("EMFObjects")  # ✅ Ensures it's in the correct group

func _process(delta):
	if current_emf > base_emf:
		current_emf = max(base_emf, current_emf - (decay_rate * delta))  # Gradual decay

func receive_emf_pulse(pulse_strength: float):
	current_emf = max(current_emf, pulse_strength)  # Store the highest EMF received
	print("📡 [DEBUG] Object received EMF Pulse:", current_emf)

func get_emf_strength() -> float:
	return current_emf
