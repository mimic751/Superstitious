extends StaticBody3D

@export var pulse_strength_min: float = 2.0
@export var pulse_strength_max: float = 5.0
@export var pulse_radius: float = 10.0

func interact():
	trigger_emf_pulse()

func trigger_emf_pulse():
	print("EMF Pulse Triggered!")
	var objects_in_range = get_tree().get_nodes_in_group("EMF_Objects")
	for obj in objects_in_range:
		var distance = global_position.distance_to(obj.global_position)
		if distance <= pulse_radius:
			var pulse_strength = randf_range(pulse_strength_min, pulse_strength_max)
			obj.receive_emf_pulse(pulse_strength)
