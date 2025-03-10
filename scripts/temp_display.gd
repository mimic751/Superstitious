extends Node3D

@onready var label = $Display_Label  # 3D Label
@onready var temp_sensor = $Temp_Sensor  # Area3D for detection

@export var temp_change_speed: float = 1.5  # How fast temp shifts

var current_temp: float = INF  # ✅ Start as INF (null-like behavior)
var target_temp: float = 20.0   # Default room temperature

func _ready():
	print("✅ [DEBUG] Temp sensor script is running!")

	if temp_sensor == null:
		push_error("❌ Temp_Sensor is MISSING!")
		return

	print("🔍 [DEBUG] Temp_Sensor found:", temp_sensor)

	# ✅ Ensure ColdZones are detected AFTER physics updates
	await get_tree().process_frame
	call_deferred("_check_initial_cold_zones")

func _check_initial_cold_zones():
	var areas = temp_sensor.get_overlapping_areas()
	print("🛠 [DEBUG] Overlapping areas after physics update:", areas.size())

	for area in areas:
		if area.is_in_group("ColdZones"):
			print("✅ [DEBUG] Already inside a ColdZone at startup!")
			_connect_temperature_signal(area)
			_on_area_entered(area)  # ✅ Manually trigger

func _connect_temperature_signal(area):
	if not area.is_connected("temperature_changed", Callable(self, "_on_temperature_changed")):
		print("🔗 [DEBUG] Connecting temperature_changed signal for:", area.name)
		area.connect("temperature_changed", Callable(self, "_on_temperature_changed"))

func _process(delta):
	# Check for currently overlapping cold zones every frame.
	var areas = temp_sensor.get_overlapping_areas()
	var active_zone = null
	for area in areas:
		if area.is_in_group("ColdZones"):
			active_zone = area
			# Optionally ensure its signal is connected.
			_connect_temperature_signal(area)
			break  # Use the first valid zone found.

	# Update target_temp based on whether we're in a zone or not.
	if active_zone:
		target_temp = active_zone.current_temperature
		# If this is the first valid reading, initialize current_temp.
		if current_temp == INF:
			current_temp = target_temp
	else:
		target_temp = 20.0  # Default temperature when not in a zone.

	# Smoothly interpolate the displayed temperature.
	if current_temp != INF:
		current_temp = lerp(current_temp, target_temp, temp_change_speed * delta)
		label.text = "%.1f°C" % current_temp
	else:
		label.text = "--.-°C"

	# ✅ Only update if current_temp is valid
	if current_temp != INF:
		current_temp = lerp(current_temp, target_temp, temp_change_speed * delta)
		label.text = "%.1f°C" % current_temp  # Update label
	else:
		label.text = "--.-°C"  # Show placeholder if no valid temp

func _on_area_entered(area):
	print("🚪 [DEBUG] Entered an area:", area.name, "Groups:", area.get_groups())

	if area.is_in_group("ColdZones"):
		print("❄️ [DEBUG] Entered a ColdZone:", area.name)

		# ✅ Ensure temperature update signal is connected
		_connect_temperature_signal(area)

		# ✅ Immediately apply detected temperature
		_on_temperature_changed(area.current_temperature)

func _on_area_exited(area):
	print("🚪 [DEBUG] Left an area:", area.name)
	
	if area.is_in_group("ColdZones"):
		print("🔥 [DEBUG] Left ColdZone:", area.name)
		current_temp = INF  # ✅ Reset to INF (null-like)
		target_temp = 20.0  # Reset temp when leaving
		label.text = "--.-°C"  # Update UI

func _on_temperature_changed(new_temp):
	#print("📡 [DEBUG] Temperature changed in zone:", new_temp)
	
	if current_temp == INF:
		print("✅ [DEBUG] First valid temperature received!")
		current_temp = new_temp  # ✅ Set only on first valid update

	target_temp = new_temp
