extends CharacterBody3D

# ------------------------------------------------
# === REFERENCES & EXPORT VARIABLES ============
# ------------------------------------------------

### Camera & Collision References
@onready var camera: Camera3D = $PlayerCamera
@onready var player_collision: CollisionShape3D = $PlayerCollision
@onready var interaction_ray: RayCast3D = $PlayerCamera/InteractionRay
@onready var hold_position: Node3D = $PlayerCamera/HoldPosition

### General Movement Variables
@export var speed: float = 5.0
@export var standing_height: float = 1.8
@export var standing_speed: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export var jump_force: float = 4.5
@export var gravity: float = 9.8

### Crouch Variables
@export var crouch_speed_modifier: float = 0.5
@export var crouch_transition_speed: float = 5.0
@export var crouch_height: float = 1.4
@export var ext_crouch: bool = false

### Sprint Variables
@export var sprint_multiplier: float = 4.0
@export var sprint_acceleration: float = 10.0
@export var sprint_deceleration: float = 10.0

### Prone Variables
@export var prone_speed_modifier: float = 0.25
@export var prone_transition_speed: float = 3.0
@export var prone_height: float = 0.8
@export var ext_prone: bool = false

### Slide Variables
@export var slide_speed_multiplier: float = 30.0
@export var slide_friction: float = 0.01
@export var slide_duration: float = 3.0
@export var slide_cooldown: float = 1.0

### Head Bobbing Variables
@export var bobbing_intensity: float = 0.5
@export var sprint_bobbing_multiplier: float = 1.5
@export var crouch_bobbing_multiplier: float = 0.5
@export var bobbing_speed: float = 7.0

### Slide Bobbing Variables
@export var slide_bump_intensity: float = 0.2

### Interaction Variables
@export var interaction_distance: float = 20
@export var hold_distance: float = 1.5
@export var throw_force: float = 8.0
@export var throw_hight: float = 1

# ------------------------------------------------
# === INTERNAL STATE VARIABLES =================
# ------------------------------------------------

var interactable_object: Node3D = null
var held_object: RigidBody3D = null

var self_crouch: bool = false
var self_sprint: bool = false
var self_slide: bool = false
var self_prone: bool = false

var slide_timer: float = 0.0
var can_slide: bool = true
var slide_bump_active: bool = false

var bobbing_timer: float = 0.0
var target_speed: float = standing_speed

var interaction_cooldown: bool = false

# ------------------------------------------------
# === READY & INPUT ============================
# ------------------------------------------------

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Ensure the interaction ray faces forward
	interaction_ray.target_position = Vector3(0, 0, -interaction_distance)

func _input(event):
	# Update movement states from input
	self_crouch = Input.is_action_pressed("crouch") or ext_crouch
	self_sprint = Input.is_action_pressed("sprint")
	
	# Initiate slide if conditions are met
	if Input.is_action_just_pressed("slide") and self_sprint and can_slide:
		self_sprint = false
		start_slide()
	
	# Toggle prone state
	if Input.is_action_just_pressed("prone") or ext_prone:
		toggle_prone()
	
	# Mouse look
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Release mouse capture on ESC
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Interactions: Pickup/Drop & Throw
	if not interaction_cooldown:
		if Input.is_action_just_pressed("interact"):
			if held_object:
				drop_held_object()
			else:
				detect_interactable()
		if Input.is_action_just_pressed("throw") and held_object:
			throw_held_object()

# ------------------------------------------------
# === PHYSICS PROCESS ============================
# ------------------------------------------------

func _physics_process(delta):
	handle_speed_states()
	apply_sprint(delta)
	handle_movement(delta)
	apply_slide(delta)
	apply_prone(delta)
	apply_crouch(delta)
	apply_camera_height(delta)
	apply_head_bob(delta)
	
	# Update held object's position
	if held_object:
		held_object.global_transform.origin = hold_position.global_transform.origin

# ------------------------------------------------
# === CAMERA & HEIGHT ADJUSTMENTS ================
# ------------------------------------------------

func apply_camera_height(delta):
	var target_camera_y = standing_height - 0.2
	if self_crouch:
		target_camera_y = crouch_height - 0.2
	elif self_slide:  # Lower the camera during a slide (adjust if needed)
		target_camera_y = crouch_height - 0.2  
	elif self_prone:
		target_camera_y = prone_height - 0.2
	camera.position.y = lerp(camera.position.y, target_camera_y, delta * crouch_transition_speed)

# ------------------------------------------------
# === MOVEMENT HANDLING ==========================
# ------------------------------------------------

func handle_movement(delta):
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		direction -= transform.basis.x
	if Input.is_action_pressed("move_right"):
		direction += transform.basis.x
	direction = direction.normalized()
	
	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Jump if on the floor
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
	
	# Only update horizontal velocity if not sliding
	if not self_slide:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	
	move_and_slide()

func handle_speed_states():
	target_speed = standing_speed
	if self_crouch:
		target_speed *= crouch_speed_modifier
	if self_prone:
		target_speed *= prone_speed_modifier
	if self_sprint and not self_crouch and not self_prone and not self_slide:
		target_speed = standing_speed * sprint_multiplier

func apply_sprint(delta):
	# Do not adjust sprint speed during a slide
	if self_slide:
		return
	if speed < target_speed:
		speed = lerp(speed, target_speed, delta * sprint_acceleration)
	else:
		speed = lerp(speed, target_speed, delta * sprint_deceleration)

# ------------------------------------------------
# === SLIDE, CROUCH, & PRONE =====================
# ------------------------------------------------

func start_slide():
	self_slide = true
	slide_timer = slide_duration
	can_slide = false
	
	# Determine slide direction (default to backward if idle)
	var slide_direction = velocity.normalized()
	if slide_direction.length() == 0:
		slide_direction = -transform.basis.z
	
	velocity = slide_direction * slide_speed_multiplier
	apply_slide_bump()
	
	# Enforce slide cooldown asynchronously
	await get_tree().create_timer(slide_cooldown).timeout
	can_slide = true

func apply_slide(delta):
	if self_slide:
		slide_timer -= delta
		# Gradually slow slide velocity
		velocity.x = lerp(velocity.x, 0.0, delta * slide_friction)
		velocity.z = lerp(velocity.z, 0.0, delta * slide_friction)
		if slide_timer <= 0:
			self_slide = false
			self_sprint = false
			self_crouch = true

func apply_crouch(delta):
	player_collision.shape.height = lerp(
		player_collision.shape.height,
		crouch_height if self_crouch else standing_height,
		delta * crouch_transition_speed
	)

func apply_prone(delta):
	player_collision.shape.height = lerp(
		player_collision.shape.height,
		prone_height if self_prone else standing_height,
		delta * prone_transition_speed
	)

func toggle_prone():
	self_prone = not self_prone
	if self_prone or ext_prone:
		self_crouch = false
	else:
		# When toggling off prone, return to standing height
		pass

func apply_slide_bump():
	if not slide_bump_active:
		slide_bump_active = true
		camera.position.y -= slide_bump_intensity
		await get_tree().create_timer(0.1).timeout
		camera.position.y += slide_bump_intensity
		slide_bump_active = false

# ------------------------------------------------
# === HEAD BOBBING ===============================
# ------------------------------------------------

func apply_head_bob(delta):
	if velocity.length() > 0.1 and is_on_floor():
		bobbing_timer += delta * bobbing_speed * (sprint_bobbing_multiplier if self_sprint else 1.0)
		var bob_intensity = bobbing_intensity
		if self_sprint:
			bob_intensity *= sprint_bobbing_multiplier
		elif self_crouch:
			bob_intensity *= crouch_bobbing_multiplier
		camera.position.y += sin(bobbing_timer) * bob_intensity * delta
	else:
		bobbing_timer = 0.0

# ------------------------------------------------
# === INTERACTION (Pickup/Drop/Throw) ===========
# ------------------------------------------------

func detect_interactable():
	# Prevent immediate re-pickup
	if interaction_cooldown:
		return
	if interaction_ray.is_colliding():
		var hit_object = interaction_ray.get_collider()
		if hit_object and hit_object is RigidBody3D and not held_object:
			pick_up_object(hit_object)

func pick_up_object(obj: RigidBody3D):
	print("Picked up:", obj.name)
	held_object = obj
	# Disable physics while held
	held_object.freeze = true
	held_object.linear_velocity = Vector3.ZERO
	held_object.angular_velocity = Vector3.ZERO
	# Disable collisions with the player
	held_object.add_collision_exception_with(self)
	# Reparent to hold position
	held_object.reparent(hold_position, true)
	held_object.transform.origin = Vector3(0, 0, -hold_distance)

func drop_held_object():
	if not held_object:
		return
	print("Dropped:", held_object.name)
	held_object.freeze = false
	held_object.remove_collision_exception_with(self)
	held_object.reparent(get_tree().root, true)
	# Offset drop position to avoid immediate pickup
	held_object.global_transform.origin = hold_position.global_transform.origin
	held_object = null
	start_interaction_cooldown()

func throw_held_object():
	if not held_object:
		return
	print("Threw:", held_object.name)
	held_object.freeze = false
	held_object.remove_collision_exception_with(self)
	held_object.reparent(get_tree().root, true)
	# Apply impulse for throw (forward + upward)
	var throw_direction = -camera.global_transform.basis.z.normalized() * throw_force
	throw_direction.y += 3.0
	held_object.apply_central_impulse(throw_direction)
	held_object = null
	start_interaction_cooldown()

func start_interaction_cooldown():
	interaction_cooldown = true
	interaction_ray.enabled = false
	await get_tree().create_timer(0.2).timeout
	interaction_ray.enabled = true
	interaction_cooldown = false
