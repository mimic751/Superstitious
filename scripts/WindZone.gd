extends Area3D

@export var base_wind_strength := 0.0  
@export var max_wind_strength := 10.0
@export var wind_lerp_speed := 5
@export var tipping_threshold := 9.0
@export var wind_force_multiplier := 1.0  # New multiplier for force adjustments
@export var impulse_multiplier := 0.5       # New multiplier for impulse strength
@export var impulse_offset := 1.0           # Increased vertical offset for impulse

var ghost_node: Node3D = null
var player_node: Node3D = null
var current_wind_strength := 0.0
var current_wind_direction := Vector3.ZERO

func _ready():
    var ghosts = get_tree().get_nodes_in_group("Ghosts")
    for ghost in ghosts:
        if ghost.name.begins_with("Ghost_"):
            ghost_node = ghost
            break

    var players = get_tree().get_nodes_in_group("Players")
    if players.size() > 0:
        player_node = players[0]

func _process(delta):
    if ghost_node and player_node:
        var ghost_activity = ghost_node.activity_level
        var target_wind_direction = (player_node.global_position - ghost_node.global_position).normalized()
        current_wind_direction = current_wind_direction.lerp(target_wind_direction, wind_lerp_speed * delta)
        var target_wind_strength = lerp(base_wind_strength, max_wind_strength, ghost_activity / 100.0)
        current_wind_strength = lerp(current_wind_strength, target_wind_strength, wind_lerp_speed * delta)
        apply_wind_to_rigid_bodies()
        apply_wind_to_particles(delta)

func apply_wind_to_rigid_bodies():
    for body in get_overlapping_bodies():
        if body is RigidBody3D:
            var adjusted_force = current_wind_direction * current_wind_strength * body.mass * wind_force_multiplier
            
            if current_wind_strength > tipping_threshold:
                var tipping_impulse = current_wind_direction * (current_wind_strength * impulse_multiplier)
                var impulse_position = body.global_position + Vector3.UP * impulse_offset
                body.apply_impulse(impulse_position, tipping_impulse)
            else:
                body.apply_central_force(adjusted_force)

func apply_wind_to_particles(delta):
    var particles = get_tree().get_nodes_in_group("Particles")
    for particle in particles:
        if particle is GPUParticles3D:
            var process_material = particle.process_material
            if process_material is ParticleProcessMaterial:
                var bend_factor = min(current_wind_strength / max_wind_strength, 1.0)
                var new_gravity = Vector3.UP * (1.0 - bend_factor) + current_wind_direction * bend_factor * 5.0
                process_material.gravity = process_material.gravity.lerp(new_gravity, wind_lerp_speed * delta)
