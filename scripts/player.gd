extends CharacterBody3D

# -------------------------------
# ✅ REFERENCES & EXPORT VARIABLES
# -------------------------------

### 🔹 Camera & Collision
@onready var camera: Camera3D = $PlayerCamera
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var interaction_ray: RayCast3D = $PlayerCamera/InteractionRay
@onready var hold_position: Node3D = $PlayerCamera/HoldPosition

### 🔹 General Movement
@export var base_speed: float = 5.0
@export var standing_height: float = 1.8
@export var mouse_sensitivity: float = 0.002
@export var jump_force: float = 4.5
@export var gravity: float = 9.8

### 🔹 Crouch & Prone
@export var crouch_speed_modifier: float = 0.5   # 50% speed when crouched
@export var crouch_height: float = 1.4
@export var prone_speed_modifier: float = 0.25    # 25% speed when prone
@export var prone_height: float = 0.8
@export var prone_transition_speed: float = 3.0

### 🔹 Sprint & Slide
@export var sprint_multiplier: float = 2.0        # Sprint is 4x faster than base
@export var sprint_ramp_time: float = 2         # Time to reach full sprint speed
@export var sprint_duration: float = 2.0          # Max sprint time
@export var sprint_cooldown: float = 3.0          # Cooldown time before sprint refills

### 🔹 Interaction Settings
@export var interaction_distance: float = 3.0
@export var hold_distance: float = 1.5
@export var throw_force: float = 8.0
@export var interaction_cooldown_time: float = 0.2

# -------------------------------
# ✅ INTERNAL STATE VARIABLES
# -------------------------------
var held_object: RigidBody3D = null
var self_crouch: bool = false
var self_sprint: bool = false
var self_prone: bool = false
var speed: float
var interaction_cooldown: bool = false

# 🔹 Sprint System
var sprint_time_left: float = 0.0
var sprinting: bool = false
var sprint_ramp_factor: float = 0.0  # Tracks sprint ramp-up progress

# -------------------------------
# ✅ CROSSHAIR HANDLING
# -------------------------------
@onready var crosshair: TextureRect = $UI/Crosshair  # Reference to UI crosshair
@export var interact_color: Color = Color(0, 1, 0, 1)  # Green when interactable
@export var grab_color: Color = Color(0, 0, 1, 1)  # Green when interactable
@export var default_color: Color = Color(1, 1, 1, 1)   # Default white

# -------------------------------
# ✅ INITIALIZATION
# -------------------------------
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interaction_ray.target_position = Vector3(0, 0, -interaction_distance)
	speed = base_speed
	sprint_time_left = sprint_duration

# -------------------------------
# ✅ INPUT HANDLING
# -------------------------------
func _input(event):
	# Set crouch state
	self_crouch = Input.is_action_pressed("crouch")
	
	# Set sprint state (only if sprint time is available)
	if Input.is_action_pressed("sprint") and sprint_time_left > 0:
		self_sprint = true
	else:
		self_sprint = false

	if Input.is_action_just_pressed("prone"):
		toggle_prone()

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Handle grabbing items
	if Input.is_action_just_pressed("Grab"):
		if held_object:
			drop_held_object()
		else:
			detect_interactable()

	# Handle throwing objects
	if Input.is_action_just_pressed("throw") and held_object:
		throw_held_object()

	# Handle interactions separately
	if Input.is_action_just_pressed("interact"):
		attempt_interact()



# -------------------------------
# ✅ MAIN PHYSICS LOOP
# -------------------------------
func _physics_process(delta):
	handle_sprint(delta)
	handle_movement(delta)
	apply_camera_height(delta)
	apply_prone(delta)  # Smoothly transition collision height for prone
	update_crosshair()

	# Keep held object in front of player
	if held_object:
		held_object.global_transform.origin = hold_position.global_transform.origin

# -------------------------------
# ✅ MOVEMENT HANDLING
# -------------------------------
func handle_movement(delta):
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"): direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"): direction += transform.basis.z
	if Input.is_action_pressed("move_left"): direction -= transform.basis.x
	if Input.is_action_pressed("move_right"): direction += transform.basis.x
	direction = direction.normalized()

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

# -------------------------------
# ✅ SPRINT SYSTEM
# -------------------------------
func handle_sprint(delta):
	if self_sprint and sprint_time_left > 0:
		sprinting = true
		sprint_time_left -= delta
		sprint_ramp_factor = min(sprint_ramp_factor + (delta / sprint_ramp_time), 1.0)
	else:
		sprinting = false
		sprint_ramp_factor = max(sprint_ramp_factor - (delta / sprint_ramp_time), 0.0)

	# Calculate sprint speed with a noticeable acceleration
	var sprint_speed = base_speed + (sprint_multiplier * base_speed * sprint_ramp_factor)

	# Apply modifiers based on state
	if self_crouch:
		speed = sprint_speed * crouch_speed_modifier
	elif self_prone:
		speed = sprint_speed * prone_speed_modifier
	else:
		speed = sprint_speed

	# Reset sprint if time is depleted
	if sprint_time_left <= 0 and sprinting:
		sprinting = false
		speed = base_speed
		await get_tree().create_timer(sprint_cooldown).timeout
		sprint_time_left = sprint_duration

# -------------------------------
# ✅ CAMERA HEIGHT HANDLING
# -------------------------------
func apply_camera_height(delta):
	var target_y = standing_height - 0.2
	if self_crouch:
		target_y = crouch_height - 0.2
	elif self_prone:
		target_y = prone_height - 0.2
	camera.position.y = lerp(camera.position.y, target_y, delta * 5.0)

# -------------------------------
# ✅ PRONE SYSTEM
# -------------------------------
func toggle_prone():
	self_prone = not self_prone
	# When going prone, disable crouch
	if self_prone:
		self_crouch = false

func apply_prone(delta):
	# Smoothly adjust collision shape height for prone vs standing
	var target_height = prone_height if self_prone else standing_height
	player_collision.shape.height = lerp(player_collision.shape.height, target_height, delta * prone_transition_speed)

# -------------------------------
# ✅ INTERACTION SYSTEM
# -------------------------------
func detect_interactable():
	if interaction_cooldown:
		return
	if interaction_ray.is_colliding():
		var hit_object = interaction_ray.get_collider()
		if hit_object is RigidBody3D:
			pick_up_object(hit_object)

func pick_up_object(obj: RigidBody3D):
	held_object = obj
	held_object.freeze = true
	held_object.add_collision_exception_with(self)
	held_object.reparent(hold_position, true)
	held_object.transform.origin = Vector3(0, 0, -hold_distance)

func drop_held_object():
	if not held_object:
		return
	held_object.freeze = false
	held_object.remove_collision_exception_with(self)
	held_object.reparent(get_tree().root, true)
	held_object.global_transform.origin = hold_position.global_transform.origin
	held_object = null
	start_interaction_cooldown()

func throw_held_object():
	if not held_object:
		return
	held_object.freeze = false
	held_object.remove_collision_exception_with(self)
	held_object.reparent(get_tree().root, true)
	var throw_direction = -camera.global_transform.basis.z.normalized() * throw_force
	throw_direction.y += 3.0
	held_object.apply_central_impulse(throw_direction)
	held_object = null
	start_interaction_cooldown()

func start_interaction_cooldown():
	interaction_cooldown = true
	await get_tree().create_timer(interaction_cooldown_time).timeout
	interaction_cooldown = false

# -------------------------------
# ✅ CROSSHAIR SYSTEM
# -------------------------------
func update_crosshair():
	if interaction_ray.is_colliding() and interaction_ray.get_collider().is_in_group("Interactables"):
		crosshair.modulate = interact_color

	elif interaction_ray.is_colliding() and interaction_ray.get_collider().is_in_group("Grab"):
		crosshair.modulate = grab_color
	else:
		crosshair.modulate = default_color

func attempt_interact():
	if interaction_ray.is_colliding():
		var hit_object = interaction_ray.get_collider()
		if hit_object.has_method("interact") and hit_object != held_object:
			hit_object.interact()
