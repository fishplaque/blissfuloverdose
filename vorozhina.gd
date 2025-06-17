extends CharacterBody3D


# ===== Ноды =====
@onready var player = get_node("/root/Scene/player")
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var damage_area: Area3D = $DamageArea
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar

# ===== Параметры =====
var max_health := 100
var health := max_health
var speed := 4.0
var attack_range := 2.0
var attack_cooldown := 1.5
var can_attack := true
var is_dead := false

func _ready():
	animation_tree.active = true
	animation_tree.set("parameters/conditions/idle", true)
	nav_agent.target_position = global_transform.origin

func _physics_process(delta):
	if is_dead:
		return

	var distance_to_player = global_transform.origin.distance_to(player.global_transform.origin)

	if has_line_of_sight():
		nav_agent.target_position = player.global_transform.origin

		if distance_to_player > attack_range:
			move_to_player(delta)
			set_animation_state("run")
		else:
			stop_moving()
			try_attack()
	else:
		stop_moving()
		set_animation_state("idle")

func has_line_of_sight() -> bool:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_transform.origin, player.global_transform.origin)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result["collider"] == player

func move_to_player(delta):
	if not nav_agent.is_navigation_finished():
		var next_path_point = nav_agent.get_next_path_position()
		var direction = (next_path_point - global_transform.origin).normalized()
		velocity = direction * speed
		move_and_slide()

func stop_moving():
	velocity = Vector3.ZERO
	move_and_slide()

func try_attack():
	if can_attack:
		set_animation_state("attack")
		can_attack = false
		attack_player()
		await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true

func attack_player():
	var overlapping_bodies = damage_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.name == "player":
			body.take_damage(10)  # Предполагается, что у игрока есть метод take_damage()

func take_damage(amount: int):
	if is_dead:
		return

	health -= amount
	health_bar.value = health
	print("Enemy health:", health)

	if health <= 0:
		die()

func die():
	is_dead = true
	set_animation_state("idle")
	queue_free()

func set_animation_state(state: String):
	match state:
		"idle":
			animation_tree.set("parameters/conditions/idle", true)
			animation_tree.set("parameters/conditions/run", false)
			animation_tree.set("parameters/conditions/attack", false)
		"run":
			animation_tree.set("parameters/conditions/idle", false)
			animation_tree.set("parameters/conditions/run", true)
			animation_tree.set("parameters/conditions/attack", false)
		"attack":
			animation_tree.set("parameters/conditions/idle", false)
			animation_tree.set("parameters/conditions/run", false)
			animation_tree.set("parameters/conditions/attack", true)
