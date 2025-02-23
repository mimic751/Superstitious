extends GPUParticles3D

### Adjustable Ranges
@export var min_distance: float = 2.0     # Below this => drift down
@export var max_distance: float = 8.0     # Above this => drift up
@export var toward_strength: float = 1.0  # Base pull toward ghost in mid-range

### Smoke Behaviors
@export var drift_up_strength: float = 5   # Upward gravity when far
@export var drift_down_strength: float = 5 # Downward gravity when very close
@export var gravity_lerp_speed: float = .3  # Smooth transition speed

### Internal
var pm: ParticleProcessMaterial

func _ready():
    # 'process_material' in GPUParticles3D is typically a GPUParticlesMaterial
    # or for CPU/GPU Particles, might be ParticleProcessMaterial in 4.x
    pm = process_material as ParticleProcessMaterial
    if pm == null:
        push_error("No valid ParticleProcessMaterial found on this GPUParticles3D node!")
        return
    else:
        print("DEBUG: Found a valid ParticleProcessMaterial.")


func _physics_process(delta):
    var ghost = find_ghost()
    if ghost == null:
        # Default full upward drift when no ghost is found
        pm.gravity = Vector3(0, drift_up_strength, 0)  # No lerp needed, just reset it
        print("DEBUG: No ghost found, resetting smoke to upward drift.")
        return


    var dist = global_transform.origin.distance_to(ghost.global_transform.origin)
    var dir_to_ghost = (ghost.global_transform.origin - global_transform.origin).normalized()

    if dist > max_distance:
        # Far away: Smoothly drift upward
        pm.gravity = pm.gravity.lerp(Vector3(0, drift_up_strength, 0), gravity_lerp_speed * delta)
    elif dist < min_distance:
        # Too close: Drift downward smoothly
        pm.gravity = pm.gravity.lerp(Vector3(0, -drift_down_strength, 0), gravity_lerp_speed * delta)
    else:
        # Middle range: Drift in a curve
        var ratio = 1.0 - (dist - min_distance) / (max_distance - min_distance)
        var pull_vec = dir_to_ghost * (ratio * toward_strength)
        
        # **Curve the pull by adding a side force**
        var cross_dir = dir_to_ghost.cross(Vector3.UP)  # Sideways force for arc effect
        pull_vec += cross_dir * (ratio * 0.5)  # Adjust the strength of sideways drift

        # **Also add a bit of upward drift so it arcs more naturally**
        pull_vec += Vector3(0, 1.0 - ratio, 0)  # Less upward force as it gets closer

        # Smoothly adjust toward the new pull vector
        pm.gravity = pm.gravity.lerp(pull_vec, gravity_lerp_speed * delta)

### Searches the scene for a CharacterBody3D named "Ghost_..."
func find_ghost() -> CharacterBody3D:
    # If your ghost is in "Ghosts" group. 
    # (Case-sensitive: "Ghosts" vs "ghosts"? Must match what's in editor.)
    for node in get_tree().get_nodes_in_group("Ghosts"):
        if node is CharacterBody3D and node.name.begins_with("Ghost_"):
            print("DEBUG: Found entity in group 'Ghosts':", node.name)
            return node

    # If not found, we return null
    print("DEBUG: No entity in group 'Ghosts' matched 'Ghost_' prefix.")
    return null
