extends Node3D

@export var jump_force: float = 100.0  # Сила подбрасывания
@onready var jump_direction = $JumpDirection
@onready var area = $Area3D

var cooldown_timer: float = 2
var affected_bodies: Dictionary = {}  # Хранит время последнего срабатывания для каждого тела

func _ready():
	area.body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Уменьшаем таймер для всех тел
	for body in affected_bodies.keys():
		affected_bodies[body] -= delta
		if affected_bodies[body] <= 0:
			affected_bodies.erase(body)

func _on_body_entered(body: Node3D):
	# Проверяем, имеет ли объект физику и не в коoldownе
	if (body is CharacterBody3D or body is RigidBody3D) and not affected_bodies.has(body):
		# Получаем направление от JumpDirection
		var direction = -jump_direction.global_transform.basis.z.normalized()
		# Применяем импульс
		if body is CharacterBody3D:
			body.velocity = direction * jump_force
		elif body is RigidBody3D:
			body.apply_central_impulse(direction * jump_force)
		# Устанавливаем коoldown для этого тела
		affected_bodies[body] = 0.5
