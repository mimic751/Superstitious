extends CharacterBody3D

@export var activity_rate := 10     # How fast activity increases per second
@export var decay_rate := 10.0       # How long it takes to decay completely
@export var activity_level := 0.0    # Starts at 0

@export var visibility_min_factor := 2  # Minimum visibility is at least half the activity level
@export var visibility_fluctuation_speed := 0.5  # Base speed of visibility oscillation
@export var visibility_fluctuation_intensity := 5  # How much visibility fluctuates

var increasing := true
var noise_intensity := 0.0  # Drives shader transparency

func _ready():
	var mat = $Ghost_mesh.get_surface_override_material(0)
	if mat is ShaderMaterial:
		print("ShaderMaterial found! Initializing shader params.")
		mat.set_shader_parameter("noise_intensity", noise_intensity)  # Initial update

func _process(delta):
	# Update activity level
	if increasing:
		activity_level = min(activity_level + (activity_rate * delta), 100.0)
		if activity_level >= 100:
			increasing = false
	else:
		activity_level = max(activity_level - (100.0 / decay_rate) * delta, 0.0)
		if activity_level <= 0:
			increasing = true

	# Base noise intensity (minimum half of activity)
	var min_intensity = activity_level * visibility_min_factor / 100.0

	# Noise fluctuation speed increases with activity_level
	var fluctuation_speed = visibility_fluctuation_speed + (activity_level / 50.0)  # Faster at higher activity

	# Compute fluctuating noise intensity
	var new_noise_intensity = min_intensity + sin(Time.get_ticks_msec() * 0.001 * fluctuation_speed) * (visibility_fluctuation_intensity / 100.0)

	# Clamp intensity between 0.0 - 2.0 (shader's range)
	new_noise_intensity = clamp(new_noise_intensity, 0.0, 2.0)

	# Only update the shader if the value has changed
	if abs(new_noise_intensity - noise_intensity) > 0.01:
		noise_intensity = new_noise_intensity
		_update_shader()

func _update_shader():
	var mat = $Ghost_mesh.get_active_material(0)  # Get the ShaderMaterial directly
	if mat is ShaderMaterial:
		print("before:", mat.get_shader_parameter("noise_intensity"))
		mat.set_shader_parameter("noise_intensity", noise_intensity)  # Apply the update
		print("after:", mat.get_shader_parameter("noise_intensity"))
