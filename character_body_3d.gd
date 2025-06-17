extends CharacterBody3D

# Свойства врага
var speed = 5.0
var gravity = 9.8
var health = 100.0
var attack_range = 2.0
var attack_damage = 20.0
var attack_cooldown = 1.0
var attack_timer = 0.0

# Ссылки на узлы
@onready var nav_agent = $NavigationAgent3D
@onready var animation_tree = $AnimationTree
@onready var attack_area = $AttackArea
@onready var player = get_tree().get_first_node_in_group("player")

# Состояния
enum State { IDLE, RUN, ATTACK }
var current_state = State.IDLE

func _ready():
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = attack_range
	animation_tree.active = true

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	attack_timer -= delta
	update_state()
	
	match current_state:
		State.IDLE:
			play_animation("idle")
			velocity.x = 0
			velocity.z = 0
		State.RUN:
			follow_player(delta)
			play_animation("run")
		State.ATTACK:
			play_animation("attack")
			try_attack()
	
	move_and_slide()

func update_state():
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player <= attack_range and attack_timer <= 0:
		current_state = State.ATTACK
	elif distance_to_player > attack_range:
		current_state = State.RUN
	else:
		current_state = State.IDLE

func follow_player(delta):
	nav_agent.set_target_position(player.global_position)
	if nav_agent.is_navigation_finished():
		return
	
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()
	var desired_velocity = direction * speed
	velocity = velocity.move_toward(desired_velocity, speed * delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	if direction.length() > 0:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, 0.1)

func try_attack():
	if attack_timer <= 0:
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("player"):
				body.take_damage(attack_damage)
		attack_timer = attack_cooldown

func play_animation(state_name: String):
	var anim_name = "1_" + state_name
	animation_tree["parameters/playback"].travel(anim_name)
	# Временно отключен блендинг до настройки BlendSpace1D
	# if state_name == "run":
	#     var speed_ratio = velocity.length() / speed
	#     animation_tree["parameters/1_run/blend_position"] = speed_ratio

func take_damage(damage: float):
	health -= damage
	if health <= 0:
		die()

func die():
	queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("player_weapon"):
		take_damage(area.damage)
