extends GPUParticles3D

@export var wind_area: Area3D  # Assign the wind Area3D node in the editor

var wind_strength := 0.0
var wind_direction := Vector3.ZERO

func _process(delta):
	if wind_area:
		var ghost_node = wind_area.ghost_node
		var player_node = wind_area.player_node

		if ghost_node and player_node:
			# Get wind direction from ghost to player
			wind_direction = (player_node.global_position - ghost_node.global_position).normalized()
			
			# Get ghost activity level (for wind strength scaling)
			wind_strength = wind_area.lerp(wind_area.base_wind_strength, wind_area.max_wind_strength, ghost_node.activity_level / 100.0)

			# Apply wind effect to particles
			var process_material = self.process_material as ParticleProcessMaterial
			if process_material:
				process_material.gravity = wind_direction * wind_strength  # Adjust gravity to push particles
