extends SpotLight3D

# Flickering
@export_range(0.0, 2.0) var flicker_strength := 1
@export var flicker_speed := 1

# Pulsing
@export var base_range := 10.0
@export var pulse_amount := 4.0
@export var pulse_speed := 0.5

# Color shifting
@export var color_shift_speed := 0.1
@export var color_saturation := 0.7
@export var color_value := 1.0

# Ghost activity highlighting
@export var illumination_threshold := 0.5
@export var highlight_energy := 2.5

var color_timer := 0.0
var base_energy := 1.0

var ghost_meshes: Array[MeshInstance3D] = []
var detection_area: Area3D

func _ready():
	randomize()
	base_energy = light_energy
	color_timer = randf_range(0, 1000)

	detection_area = get_node("../DetectionArea")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	# Flicker Intensity
	var noise_val = randf_range(-1.0, 1.0)
	var intensity = clamp(base_energy + noise_val * flicker_strength, 0.3, 2.0)
	light_energy = intensity

	# Pulsing Range
	var pulse = sin(Time.get_ticks_msec() * 0.002 * pulse_speed)
	spot_range = base_range + pulse * pulse_amount

	# Color Shifting
	color_timer += flicker_speed * delta * color_shift_speed
	var hue = fmod(color_timer, 1.0)
	var new_color = Color.from_hsv(hue, color_saturation, color_value)
	light_color = new_color

	# Update detected ghost shaders
	for ghost in ghost_meshes:
		var ghost_material = ghost.get_active_material(0)
		if ghost_material is ShaderMaterial:
			var transparency_factor = clamp(light_energy / highlight_energy, 0.1, 1.0)
			ghost_material.set_shader_parameter("ghost_alpha", transparency_factor)
			ghost_material.set_shader_parameter("ghost_tint", light_color)

func _on_body_entered(body):
	if body is CharacterBody3D:
		var mesh_instance = body.get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance not in ghost_meshes:
			ghost_meshes.append(mesh_instance)

func _on_body_exited(body):
	if body is CharacterBody3D:
		var mesh_instance = body.get_node_or_null("MeshInstance3D")
		if mesh_instance and mesh_instance in ghost_meshes:
			ghost_meshes.erase(mesh_instance)
