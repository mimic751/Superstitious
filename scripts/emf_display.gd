extends Node3D

@onready var label = $Display_Label  # 3D Label
@onready var EMF_sensor = $EMF_Sensor  # Area3D for detection

@export var EMF_change_speed: float = 1.5  # How fast EMF shifts
@export var object_detection_radius: float = 3.0  # ✅ Max range of EMF detection
@export var full_detection_range: float = 0.5  # ✅ 100% detection range
@export var min_detection_range: float = 3.0  # ✅ 1% detection range

var current_EMF: float = INF  # ✅ Start as INF (null-like behavior)
var target_EMF: float = 0.0   # Default EMF (updated dynamically)

func _ready():
    print("✅ [DEBUG] EMF sensor script is running!")

    if EMF_sensor == null:
        push_error("❌ EMF_Sensor is MISSING!")
        return

    print("🔍 [DEBUG] EMF_Sensor found:", EMF_sensor)
    await get_tree().process_frame
    call_deferred("_check_initial_EMF_zones")

func _check_initial_EMF_zones():
    var areas = EMF_sensor.get_overlapping_areas()
    for area in areas:
        if area.is_in_group("EMFZones"):
            _connect_EMF_signal(area)
            _on_EMF_changed(area.get_emf_strength())

func _connect_EMF_signal(area):
    if not area.is_connected("emf_changed", Callable(self, "_on_EMF_changed")):
        area.connect("emf_changed", Callable(self, "_on_EMF_changed"))

func _process(delta):
    var detected_emf_zones = _get_active_emf_zones()
    var detected_emf_objects = _get_active_emf_objects()

    # ✅ Now correctly applies falloff
    target_EMF = max(detected_emf_zones, detected_emf_objects)

    # ✅ Smoothly interpolate displayed EMF
    if current_EMF == INF:
        current_EMF = target_EMF
    else:
        current_EMF = lerp(current_EMF, target_EMF, EMF_change_speed * delta)

    # ✅ Update label
    label.text = "%.1f mA" % current_EMF

func _get_active_emf_zones() -> float:
    var highest_zone_emf = 0.0
    var areas = EMF_sensor.get_overlapping_areas()

    for area in areas:
        if area.is_in_group("EMFZones"):
            var distance = global_position.distance_to(area.global_position)
            var scaled_emf = apply_falloff(area.get_emf_strength(), distance)
            highest_zone_emf = max(highest_zone_emf, scaled_emf)
            _connect_EMF_signal(area)

    return highest_zone_emf

func _get_active_emf_objects() -> float:
    var highest_object_emf = 0.0
    var nearby_objects = get_tree().get_nodes_in_group("EMFObjects")

    for obj in nearby_objects:
        if obj is RigidBody3D:
            var distance = global_position.distance_to(obj.global_position)
            if distance <= object_detection_radius:
                if obj.has_method("get_emf_strength"):
                    var obj_emf = obj.get_emf_strength()
                    var scaled_emf = apply_falloff(obj_emf, distance)
                    highest_object_emf = max(highest_object_emf, scaled_emf)

    return highest_object_emf

func apply_falloff(emf_value: float, distance: float) -> float:
    if distance <= full_detection_range:
        return emf_value  # ✅ 100% detection at 0.5m or closer
    elif distance >= min_detection_range:
        return emf_value * 0.01  # ✅ 1% detection at 3m or further
    else:
        var scale_factor = inverse_lerp(min_detection_range, full_detection_range, distance)
        return emf_value * scale_factor  # ✅ Smooth transition between 100% → 1%

func _on_EMF_changed(new_EMF):
    target_EMF = new_EMF
