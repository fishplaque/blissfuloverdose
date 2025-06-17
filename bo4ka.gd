extends RigidBody3D

func _ready():
	apply_central_impulse(Vector3(0, 5, 0)) # Толчок вверх
