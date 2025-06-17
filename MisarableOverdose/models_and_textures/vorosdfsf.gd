extends CharacterBody3D

@export var max_health: int = 100
@export var speed: float = 15.0
@export var rotation_speed: float = 5.0
@export var gravity: float = 9.8
@export var attack_cooldown: float = 2.0
@export var attack_damage: int = 10
@export var player_path : NodePath
@onready var animation_tree : AnimationTree = $vorozhina/AnimationTree
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area3D = $Area3D
@onready var player: Node3D = get_node("/root/Scene/player")  # Измени путь, если нужно

var current_health: int = max_health
var is_attacking: bool = false
var attack_timer: float = 0.0
var velocity_y = 0


func _ready():
	nav_agent.target_position = player.global_transform.origin
	#attack_area.body_entered.connect(_on_attack_area_body_entere
	print("gay sex super dildo")
	#attack_area.body_exited.connect(_on_attack_area_body_exited)

func _physics_process(delta):
	velocity_y = velocity.y
	if current_health <= 0:
		return
	
	nav_agent.set_target_position(player.global_transform.origin)
	var next_nav_point = nav_agent.get_next_path_position()
	velocity = (next_nav_point - global_position).normalized() * speed
	look_at(next_nav_point)
	rotation.x = 0
	
	# Навигация к цели
	nav_agent.target_position = player.global_transform.origin

	#var direction = Vector3.ZERO
	#if not nav_agent.is_navigation_finished():
		#direction = (nav_agent.get_next_path_position() - global_transform.origin).normalized()
#
	## Плавный поворот к игроку
	#if direction.length() > 0.1:
		#var target_rotation = atan2(direction.x, direction.z)
		#rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
#
	### Движение и гравитация
	#if is_attacking:
		#velocity.x = 0
		#velocity.z = 0
		#play_animation("1_attack")
	#else:
		#if direction.length() > 0.1:
			#velocity.x = direction.x * speed
			#velocity.z = direction.z * speed
			#play_animation("1_run")
		#else:
			#velocity.x = 0
			#velocity.z = 0
			#play_animation("1_idle")

	# Применение гравитации
	velocity.y = velocity_y
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	move_and_slide()

func take_damage(damage: int):
	current_health -= damage
	print("Enemy took damage:", damage, "→ health:", current_health)

	if current_health <= 0:
		die()

func die():
	print("Enemy died")
	queue_free()

func play_animation(name: String):
	if not anim_player.is_playing() or anim_player.current_animation != name:
		anim_player.play(name)
