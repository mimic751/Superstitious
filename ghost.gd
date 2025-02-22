extends CharacterBody3D

# Ghost Properties
@export var ghost_name = "Unnamed Ghost"
@export var visibility_state = 0  # 0 = Invisible, 1 = Partial, 2 = Full
@export var phase_through_objects = true
@export var teleport_cooldown = 5.0
@export var sound_effect_intensity = 1.0  # 0 = Silent, 1 = Normal, 2 = Loud
@export var shadow_mode = false
@export var interaction_chance = 0.3  # Chance for ghost to interact with objects
@export var haunting_type = "Roaming"  # Options: "Room-Bound", "Object-Attached"
@export var fog_intensity = 0.5  # Controls fog thickness
@export var physical_interaction_chance = 0.3  # 30% chance to move objects
@export var marking_chance = 0.2  # Chance to leave handprints, ectoplasm
@export var aggression_level = 0  # Scales with environment (state-based)
@export var attack_behavior = 0  # 0 = Harmless, 1 = Push, 2 = Grab

var player = null  # Assigned when the player enters range

func _ready():
	set_visibility_state(0)  # Start invisible
	$AudioStreamPlayer3D.volume_db = linear_to_db(sound_effect_intensity)

func _process(delta):
	if player:
		handle_proximity_effects(player.global_position.distance_to(global_position))

# Handles visibility, fog, and sound based on distance
func handle_proximity_effects(distance):
	if distance < 3:
		set_visibility_state(2) # Full apparition
	elif distance < 8:
		set_visibility_state(1) # Partial apparition
	else:
		set_visibility_state(0) # Invisible

func set_visibility_state(state):
	visibility_state = state
	match state:
		0: # Invisible
			$MeshInstance3D.visible = false
			$FogVolume3D.visible = false
		1: # Partial Apparition
			$MeshInstance3D.visible = true
			$FogVolume3D.visible = true
			$MeshInstance3D.material_override.albedo_color.a = 0.5
		2: # Full Apparition
			$MeshInstance3D.visible = true
			$FogVolume3D.visible = true
			$MeshInstance3D.material_override.albedo_color.a = 1.0

# Handles teleporting ghosts
func teleport():
	var new_location = get_random_teleport_location()
	if new_location:
		global_position = new_location
		print(ghost_name, "teleported!")

# Generates a random teleport position within a set area
func get_random_teleport_location():
	var max_attempts = 10  # Prevent infinite loops
	var attempt = 0
	var new_position = Vector3.ZERO

	while attempt < max_attempts:
		attempt += 1
		new_position = global_position + Vector3(
			randf_range(-10, 10),  # Random X offset
			0,                     # Keep Y the same (unless vertical movement is allowed)
			randf_range(-10, 10)   # Random Z offset
		)

		# Perform a simple check: Ensure ghost is not teleporting inside a wall
		if not is_position_inside_wall(new_position):
			return new_position

	print("Teleport failed - No valid locations found")
	return null  # No valid teleport found

# Checks if the ghost is teleporting inside a wall (Replace this with actual collision detection)
func is_position_inside_wall(position: Vector3) -> bool:
	var space_state = get_world_3d().direct_space_state

# Shadow Mode: Ghost casts shadows but is not visible
func enable_shadow_mode():
	shadow_mode = true
	$Light3D.visible = true

# Detects when the player enters or leaves the ghost's area
func _on_Area3D_body_entered(body):
	if body.name == "Player":
		player = body

func _on_Area3D_body_exited(body):
	if body.name == "Player":
		player = null
