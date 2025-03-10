extends StaticBody3D

@export var pulse_strength_min: float = 2.0
@export var pulse_strength_max: float = 5.0
@export var pulse_radius: float = 10.0
@export var target_object_name: String = "TestObject_grab_Emfable"  # ✅ Set your target object

func interact():
	trigger_emf_pulse()

func trigger_emf_pulse():
	print("⚡ EMF Pulse Triggered! Targeting:", target_object_name)

	# ✅ Find the specific target object
	var target_object = get_tree().get_nodes_in_group("EMFObjects").filter(func(obj): return obj.name == target_object_name)

	if target_object.size() > 0:
		var obj = target_object[0]  # Get the object
		var distance = global_position.distance_to(obj.global_position)

		if distance <= pulse_radius:
			var pulse_strength = randf_range(pulse_strength_min, pulse_strength_max)
			obj.receive_emf_pulse(pulse_strength)
			print("📡 [DEBUG] EMF applied to:", obj.name, "| Strength:", pulse_strength)
		else:
			print("⚠️ [DEBUG] Target is out of range! Distance:", distance)
	else:
		print("❌ [ERROR] Target object not found in EMFObjects group.")
