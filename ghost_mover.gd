extends PathFollow3D

@export var move_speed := .5  # Adjust this for overall speed
var direction := 1  # 1 = forward, -1 = backward

func _process(delta):
	# Ensure uniform movement by adjusting the speed based on curve length
	var path_length = get_parent().curve.get_baked_length()
	var normalized_speed = (move_speed / path_length) * delta

	progress_ratio += normalized_speed * direction

	# Reverse direction at path ends
	if progress_ratio >= 1.0:
		progress_ratio = 1.0  # Stop at the end before reversing
		direction = -1
	elif progress_ratio <= 0.0:
		progress_ratio = 0.0  # Stop at the start before reversing
		direction = 1
