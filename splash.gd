extends Node3D

func _ready():
	var timer = $Decal/Timer
	if timer:
		timer.wait_time = 1.0
		timer.one_shot = true
		timer.start()
		timer.timeout.connect(_on_timer_timeout)
	else:
		print("Error: Timer node not found in Splash scene!")

func _on_timer_timeout():
	queue_free()
