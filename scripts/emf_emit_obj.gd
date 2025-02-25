extends RigidBody3D

@export var base_emf: float = 1.5
@export var pulse_min: float = 0.5
@export var pulse_max: float = 2.5
@export var is_powered: bool = true
@export var pulse_interval: float = 8.0
var picked_up = false
var current_emf: float = 0.0
var pulse_timer: Timer

func _ready():
	current_emf = base_emf if is_powered else 0.0
	pulse_timer = Timer.new()
	pulse_timer.wait_time = pulse_interval
	pulse_timer.one_shot = false
	pulse_timer.timeout.connect(_on_pulse_timer_timeout)
	add_child(pulse_timer)
	pulse_timer.start()

func interact():
	if not picked_up:  # Only toggle power if the object isn't being held
		toggle_power()

func toggle_power():
	is_powered = !is_powered
	current_emf = base_emf if is_powered else 0.0
	print("Device toggled:", is_powered)

func _on_pulse_timer_timeout():
	if is_powered:
		print("power on")
		var pulse_strength = randf_range(pulse_min, pulse_max)
		current_emf = base_emf + pulse_strength
		await get_tree().create_timer(1.5).timeout
		current_emf = base_emf

func get_emf_strength() -> float:
	return current_emf if is_powered else 0.0

func grab():
	picked_up = !picked_up
	freeze = picked_up  # Stops physics when picked up

	if picked_up:
		print("Picked up!")
	else:
		print("Dropped!")
