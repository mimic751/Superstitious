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
@export var crouch_speed_modifier: float = 0.5
@export var crouch_height: float = 1.4
@export var prone_speed_modifier: float = 0.25
@export var prone_height: float = 0.8
@export var prone_transition_speed: float = 3.0

### 🔹 Sprint & Slide
@export var sprint_multiplier: float = 10
@export var slide_speed_multiplier: float = 30.0
@export var slide_duration: float = 3.0
@export var slide_cooldown: float = 1.0
@export var slide_friction: float = 0.01
@export var slide_bump_intensity: float = 0.2

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
var self_slide: bool = false
var self_prone: bool = false
var can_slide: bool = true
var slide_timer: float = 0.0
var bobbing_timer: float = 0.0
var speed: float
var interaction_cooldown: bool = false

# -------------------------------
# ✅ CROSSHAIR HANDLING
# -------------------------------
@onready var crosshair: TextureRect = $UI/Crosshair  # Reference to UI crosshair
@export var interact_color: Color = Color(0, 1, 0, 1)  # Green when interactable
@export var default_color: Color = Color(1, 1, 1, 1)  # Default white

# -------------------------------
# ✅ INITIALIZATION
# -------------------------------
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	interaction_ray.target_position = Vector3(0, 0, -interaction_distance)
	speed = base_speed

# -------------------------------
# ✅ INPUT HANDLING
# -------------------------------
func _input(event):
	self_crouch = Input.is_action_pressed("crouch")
	self_sprint = Input.is_action_pressed("sprint")

	if Input.is_action_just_pressed("slide") and self_sprint and can_slide:
		start_slide()

	if Input.is_action_just_pressed("prone"):
		toggle_prone()

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Interaction handling
	if Input.is_action_just_pressed("interact"):
		if held_object:
			drop_held_object()
		else:
			detect_interactable()

	if Input.is_action_just_pressed("throw") and held_object:
		throw_held_object()

# -------------------------------
# ✅ MAIN PHYSICS LOOP
# -------------------------------
func _physics_process(delta):
	handle_movement(delta)
	apply_camera_height(delta)
	update_crosshair()

	# Keep object in front of player if held
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

	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

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
	if self_prone:
		self_crouch = false
		speed = base_speed * prone_speed_modifier
	else:
		speed = base_speed

func apply_prone(delta):
	player_collision.shape.height = lerp(
		player_collision.shape.height,
		prone_height if self_prone else standing_height,
		delta * prone_transition_speed
	)

# -------------------------------
# ✅ SLIDE HANDLING
# -------------------------------
func start_slide():
	self_slide = true
	slide_timer = slide_duration
	can_slide = false

	var slide_direction = velocity.normalized()
	if slide_direction.length() == 0:
		slide_direction = -transform.basis.z

	velocity = slide_direction * slide_speed_multiplier
	apply_slide_bump()

	await get_tree().create_timer(slide_cooldown).timeout
	can_slide = true

func apply_slide_bump():
	camera.position.y -= slide_bump_intensity
	await get_tree().create_timer(0.1).timeout
	camera.position.y += slide_bump_intensity

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
	else:
		crosshair.modulate = default_color
