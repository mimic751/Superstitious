extends GPUParticles3D

### ✅ Adjustable Ranges
@export var min_distance: float = 1   # Below this => drift down
@export var max_distance: float = 10.0     # Above this => drift up
@export var toward_strength: float = 1.0  # Base pull toward ghost in mid-range

### ✅ Smoke Behaviors
@export var drift_up_strength: float = .5   # Upward force when far
@export var drift_down_strength: float = 10.0 # Strong downward pull when very closeawa
@export var gravity_lerp_speed: float = 1.0  # Smooth transition speed

### ✅ Particle Control
@export var initial_upward_velocity: float = .3  # Initial rising speed
@export var acceleration_strength: float = 4.0    # Strength of attraction to ghost
@export var side_drift_factor: float = 1.5      # Sideways drift in arc

@export var turbulence_strength: float = 0.75  # Controls random movement
@export var max_random_turbulence: float = 1  # Adds slight randomness to movement

### ✅ Internal
var pm: ParticleProcessMaterial

func _ready():
    pm = process_material as ParticleProcessMaterial
    if pm == null:
        push_error("❌ No valid ParticleProcessMaterial found on this GPUParticles3D node!")
        return

    print("✅ DEBUG: Found valid ParticleProcessMaterial.")

    # Initial particle behavior
    pm.initial_velocity_min = initial_upward_velocity * 0.8
    pm.initial_velocity_max = initial_upward_velocity * 1.2

    # ✅ Ensure particles move up IMMEDIATELY in **global** Y-direction
    pm.gravity = Vector3.UP * drift_up_strength

func apply_turbulence():
    var random_x = randf_range(-max_random_turbulence, max_random_turbulence)
    var random_z = randf_range(-max_random_turbulence, max_random_turbulence)
    return Vector3(random_x, 0, random_z)  # Small random horizontal push

func _physics_process(delta):
    var ghost = find_ghost()
    
    # ✅ Start with a stable base gravity vector (prevents accumulation)
    var new_gravity = Vector3.UP * drift_up_strength  # **Forces global upward Y movement**

    if ghost == null:
        # ✅ Default smooth upward drift with slight turbulence
        new_gravity += apply_turbulence()
    else:
        var dist = global_transform.origin.distance_to(ghost.global_transform.origin)
        var dir_to_ghost = (ghost.global_transform.origin - global_transform.origin).normalized()

        if dist < min_distance:
            # ✅ Too close: Strong downward pull (Global Y-Axis)
            new_gravity = Vector3.DOWN * drift_down_strength
        elif dist < max_distance:
            # ✅ Drift towards ghost in an arc
            var ratio = 1.0 - (dist - min_distance) / (max_distance - min_distance)
            var pull_vec = dir_to_ghost * (ratio * toward_strength)

            # ✅ Introduce sideways drift for a curving effect
            var cross_dir = dir_to_ghost.cross(Vector3.UP)
            pull_vec += cross_dir * (ratio * side_drift_factor)

            # ✅ Ensure Y-axis remains **global up**
            pull_vec.y += (1.0 - ratio) * 0.5  # Keep slight upward movement

            # ✅ Add turbulence for randomness
            pull_vec += apply_turbulence()

            new_gravity = pull_vec

    # ✅ Smoothly adjust towards the calculated gravity without overriding motion
    pm.gravity = pm.gravity.lerp(new_gravity, gravity_lerp_speed * delta)

### ✅ Finds the nearest CharacterBody3D with name starting "Ghost_"
func find_ghost() -> CharacterBody3D:
    for node in get_tree().get_nodes_in_group("Ghosts"):
        if node is CharacterBody3D and node.name.begins_with("Ghost_"):
            print("👻 DEBUG: Found entity in 'Ghosts' group:", node.name)
            return node

    print("❌ DEBUG: No entity in 'Ghosts' matched 'Ghost_' prefix.")
    return null
