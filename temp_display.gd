extends Node3D

@onready var temp_sensor = $Temp_Sensor  # Reference to Area3D
@onready var label = $Display_Label  # Reference to 3D Label

# Default ambient temperature
@export var default_temp: float = 20.0  # Room temp
@export var cold_spot_temp: float = -5.0  # Deep ghost effect
@export var temp_change_speed: float = 1.0  # Rate of temp shift

var current_temp: float = 20.0  # Tracks live temp

func _ready():
	temp_sensor.connect("area_entered", _on_area_entered)
	temp_sensor.connect("area_exited", _on_area_exited)

func _process(delta):
	# Smoothly adjust temp towards the environment state
	current_temp = lerp(current_temp, default_temp, temp_change_speed * delta)
	label.text = "Temp: %.1f°C" % current_temp  # Update display

func _on_area_entered(area):
	if area.is_in_group("ColdZones"):
		default_temp = cold_spot_temp  # Lower temp when in a cold zone
		print("Entered cold spot!")

func _on_area_exited(area):
	if area.is_in_group("ColdZones"):
		default_temp = 20.0  # Reset when leaving a cold zone
		print("Left cold spot!")
