extends CharacterBody3D

@export var health: int = 100
@export var speed: float = 3.0
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5  # секунды между атаками

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var animator: AnimationPlayer = $AnimationPlayer  # или AnimatedSprite3D, если используете
@onready var audio_attack: AudioStreamPlayer = $AudioAttack
@onready var audio_hurt: AudioStreamPlayer = $AudioHurt

var attack_timer: float = 0.0
var dead: bool = false
var player: Node3D = null

func _ready():
	# Найти игрока в сцене (укажите правильный путь к игроку)
	player = get_node("/root/World/Player")
	navigation_agent.target_position = player.global_position

func _physics_process(delta):
	if dead:
		return

	# Обновляем цель навигации — позицию игрока
	navigation_agent.target_position = player.global_position

	# Если навигация еще не закончена, двигаемся к следующей точке пути
	if not navigation_agent.is_navigation_finished():
		var next_pos = navigation_agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = 0
		velocity.z = 0

	# Гравитация
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Проверяем дистанцию до игрока для атаки
	var distance_to_player = global_position.distance_to(player.global_position)
	attack_timer -= delta
	if distance_to_player <= attack_range and attack_timer <= 0:
		attack()
		attack_timer = attack_cooldown

func attack():
	if dead:
		return
	# Проигрываем анимацию атаки и звук
	animator.play("attack")
	audio_attack.play()
	# Наносим урон игроку (предполагается, что у игрока есть метод receive_damage)
	if player.has_method("receive_damage"):
		player.receive_damage(attack_damage)

func receive_damage(amount: int):
	if dead:
		return
	health -= amount
	animator.play("hurt")
	audio_hurt.play()
	if health <= 0:
		die()

func die():
	dead = true
	animator.play("die")
	navigation_agent.set_enabled(false)
	velocity = Vector3.ZERO
	await get_tree().create_timer(2.0).timeout
	queue_free()
