extends RigidBody3D

var picked_up = false

func interact():
	picked_up = !picked_up
	freeze = picked_up  # Stops physics when picked up

	if picked_up:
		print("Picked up!")
	else:
		print("Dropped!")
