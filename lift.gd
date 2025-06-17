extends Node3D

@export var move_height: float = 6.0
@export var move_time: float = 0.2
@export var pause_time: float = 1  # Задержка вверху/внизу

func _ready():
	start_bounce_with_pause()

func start_bounce_with_pause():
	var tween = create_tween().set_loops()
	var start_y = position.y
	var end_y = start_y + move_height
	
	tween.tween_property(self, "position:y", end_y, move_time).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(pause_time)  # Пауза вверху
	tween.tween_property(self, "position:y", start_y, move_time).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(pause_time)  # Пауза внизу
