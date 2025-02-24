extends CharacterBody3D

@export var activity_rate := 1  # How fast activity increases per second
@export var decay_rate := 10.0  # How long it takes to decay completely
@export var activity_level := 0.0  # Starts at 0

var increasing := true  # Tracks whether activity is increasing or decreasing

func _process(delta):
	if increasing:
		# Increase activity up to 100
		activity_level = min(activity_level + (activity_rate * delta), 100.0)
		if activity_level >= 100:
			increasing = false  # Switch to decreasing once maxed
	else:
		# Gradually decay activity to 0
		activity_level = max(activity_level - (100.0 / decay_rate) * delta, 0.0)
		if activity_level <= 0:
			increasing = true  # Restart increasing when it reaches 0
