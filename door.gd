extends Node3D

@onready var animation_player = $AnimationPlayer
@onready var area = $Area3D
var is_open = false

func _ready():
	area.body_entered.connect(_on_area_3d_body_entered)

func _on_area_3d_body_entered(body):
	if body.is_in_group("player") and not is_open:
		animation_player.play("open_door")
		is_open = true
