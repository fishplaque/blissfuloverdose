extends Node3D

@export var force_strength: float = 10000000000.0  # Максимальная сила потока
@export var force_direction: Vector3 = Vector3(0, 0, 1)  # Направление
@export var use_direction_node: bool = true  # Использовать DirectionNode?
@export var acceleration_rate: float = 99999999999.0  # Скорость нарастания силы

@onready var direction_node = $DirectionNode
@onready var force_area = $ForceArea

var affected_body: CharacterBody3D = null
var current_force: float = 0.0

func _ready():
	force_area.body_entered.connect(_on_body_entered)
	force_area.body_exited.connect(_on_body_exited)
	force_direction = force_direction.normalized()

func _physics_process(delta):
	var direction = force_direction if not (use_direction_node and direction_node) else -direction_node.global_transform.basis.z.normalized()
	
	if affected_body:
		current_force = min(current_force + acceleration_rate * delta, force_strength)
		affected_body.velocity += direction * current_force * delta
	else:
		current_force = max(current_force - acceleration_rate * delta, 0.0)

func _on_body_entered(body: Node3D):
	if body is CharacterBody3D:
		affected_body = body

func _on_body_exited(body: Node3D):
	if body == affected_body:
		affected_body = null
