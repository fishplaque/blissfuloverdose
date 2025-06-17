extends Node3D

@onready var area = $Area3D

func _ready():
	area.body_entered.connect(_on_area_3d_body_entered)

func _on_area_3d_body_entered(body):
	if body.is_in_group("player"):
		queue_free() # Удаляет узел и всех его дочерних узлов из сцены
