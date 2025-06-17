extends CharacterBody3D

@export var mouse_sensitivity: float = 0.1
@export var move_speed: float = 30.0
@export var jump_velocity: float = 20.5
@export var second_jump_multiplier: float = 1.7
@export var dash_force: float = 70.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 0.2
@export var gravity_acceleration: float = 70.0
@export var max_fall_speed: float = 150.0
@export var max_jumps: int = 3
@export var max_air_dashes: int = 3

@export var base_fov: float = 90.0
@export var max_fov: float = 130.0
@export var fov_change_speed: float = 8.0
@export var fov_sensitivity: float = 0.05
@export var dash_fov_boost: float = 10.0
@export var fov_recovery_speed: float = 1.0

# Параметры грапплинг-хука
@export var hook_range: float = 50.0
@export var hook_pull_speed: float = 100.0
@export var hook_min_distance: float = 10.0
@export var hook_impulse_strength: float = 100.0
@export var hook_swing_factor: float = 70.0

# Параметры движения в стиле Quake/Dusk
@export var accel: float = 14
@export var friction: float = 10.0
@export var air_control: float = 1.2
@export var air_friction: float = 0.8

# Здоровье игрока
@export var health: float = 100.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
var rotation_x: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var is_dashing: bool = false
var dash_direction: Vector3 = Vector3.ZERO
var jump_count: int = 0
var air_dash_count: int = 0
var fall_time: float = 0.0
var current_fov_boost: float = 0.0

# Переменные для грапплинг-хука
var is_hooked: bool = false
var hook_target: Vector3 = Vector3.ZERO
var hook_target_node: Node3D = null
var hook_velocity: Vector3 = Vector3.ZERO

@onready var camera: Camera3D = $Camera3D
@onready var shotgun = $Camera3D/WeaponManager/WeaponRoot/Shotgun
@onready var hook_raycast: RayCast3D = $Camera3D/HookRayCast
@onready var hook_line: MeshInstance3D = $Camera3D/HookLine

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = base_fov
	setup_hook_line()

func setup_hook_line() -> void:
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = 1.0
	hook_line.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0, 0, 0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hook_line.material_override = material
	hook_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hook_line.visible = false

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	handle_jumping()
	handle_dashing(delta)
	handle_hook(delta)
	handle_movement(delta)
	update_fov(delta)
	update_hook_line()
	move_and_slide()

func handle_hook(delta: float) -> void:
	if is_hooked:
		if Input.is_action_just_pressed("hook") or Input.is_action_just_pressed("ui_accept"):
			apply_hook_impulse()
			stop_hook()
			return

	if is_hooked and hook_target_node:
		var distance_to_target = global_position.distance_to(hook_target)
		if distance_to_target < hook_min_distance:
			stop_hook()
			return
		var direction = (hook_target - global_position).normalized()
		hook_velocity = hook_velocity.lerp(direction * hook_pull_speed, delta * 5.0)
		velocity = hook_velocity
		var turn_input = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		if turn_input != 0:
			var right_vector = global_transform.basis.x
			velocity += right_vector * turn_input * hook_swing_factor

	if Input.is_action_just_pressed("hook") and not is_hooked:
		try_hook()

func try_hook() -> void:
	hook_raycast.force_raycast_update()
	if hook_raycast.is_colliding():
		var collider = hook_raycast.get_collider()
		if collider and collider.is_in_group("grappleable"):
			is_hooked = true
			hook_target = hook_raycast.get_collision_point()
			hook_target_node = collider
			velocity.y = 0
			fall_time = 0.0
			hook_velocity = Vector3.ZERO

func stop_hook() -> void:
	is_hooked = false
	hook_target_node = null
	hook_target = Vector3.ZERO

func apply_hook_impulse() -> void:
	velocity = hook_velocity.normalized() * hook_impulse_strength

func update_hook_line() -> void:
	if is_hooked:
		var to_target = hook_target - global_position
		var distance = to_target.length()
		hook_line.mesh.height = distance
		hook_line.global_position = global_position + to_target * 0.5
		if to_target != Vector3.ZERO:
			hook_line.rotation = Vector3.ZERO
			hook_line.look_at(hook_target, Vector3.UP)
			hook_line.rotate_x(deg_to_rad(90))
		hook_line.visible = true
	else:
		hook_line.visible = false

func handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_hooked:
		fall_time += delta
		var current_gravity: float = gravity + gravity_acceleration * fall_time
		velocity.y = maxf(velocity.y - current_gravity * delta, -max_fall_speed)
	else:
		fall_time = 0.0
		jump_count = 0
		air_dash_count = 0

func handle_jumping() -> void:
	if Input.is_action_just_pressed("ui_accept") and (is_on_floor() or jump_count < max_jumps):
		velocity.y = jump_velocity * (second_jump_multiplier if jump_count > 0 else 1.0)
		jump_count += 1

func handle_dashing(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0:
		if is_on_floor() or air_dash_count < max_air_dashes:
			start_dash()
			if not is_on_floor():
				air_dash_count += 1

	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
	
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)

func handle_movement(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var wish_dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if is_dashing or is_hooked:
		pass
	else:
		if is_on_floor():
			var speed = Vector3(velocity.x, 0, velocity.z).length()
			if speed > 0:
				var drop = speed * friction * delta
				var new_speed = max(speed - drop, 0) / speed
				velocity.x *= new_speed
				velocity.z *= new_speed
			accelerate(wish_dir, move_speed, accel, delta)
		else:
			var speed = Vector3(velocity.x, 0, velocity.z).length()
			if speed > 0:
				var drop = speed * air_friction * delta
				var new_speed = max(speed - drop, 0) / speed
				velocity.x *= new_speed
				velocity.z *= new_speed
			accelerate(wish_dir, move_speed, accel * air_control, delta)

	if input_dir != Vector2.ZERO:
		shotgun.update_state("run_sg")
	else:
		shotgun.update_state("idle_sg")

func accelerate(wish_dir: Vector3, max_speed: float, acceleration: float, delta: float) -> void:
	var current_speed = Vector3(velocity.x, 0, velocity.z).dot(wish_dir)
	var add_speed = max_speed - current_speed
	if add_speed <= 0:
		return
	var accel_speed = min(add_speed, acceleration * max_speed * delta)
	velocity += wish_dir * accel_speed

func update_fov(delta: float) -> void:
	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	# Используем экспоненциальную зависимость для плавного роста FOV
	var fov_increase = (max_fov - base_fov) * (1.0 - exp(-horizontal_speed * fov_sensitivity))
	var target_fov = base_fov + fov_increase
	# Добавляем эффект FOV от даша
	if is_dashing:
		target_fov += dash_fov_boost
	# Ограничиваем target_fov, чтобы не превышать max_fov + dash_fov_boost
	target_fov = clamp(target_fov, base_fov, max_fov + (dash_fov_boost if is_dashing else 0.0))
	# Плавно изменяем FOV
	camera.fov = lerpf(camera.fov, target_fov, delta * fov_change_speed)

func start_dash() -> void:
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() if input_dir != Vector2.ZERO else -transform.basis.z
	velocity.x = dash_direction.x * dash_force
	velocity.z = dash_direction.z * dash_force

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_x = clampf(rotation_x, -90.0, 90.0)
		camera.rotation.x = deg_to_rad(rotation_x)
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
	
	# Обработка нажатия ЛКМ ("shoot")
	if event.is_action_pressed("shoot"):
		# Проверяем, смотрит ли игрок на дверь
		var door = check_for_door()
		if door and door.is_player_near:
			# Если игрок рядом с дверью и смотрит на неё, открываем дверь
			door.open_door()
		else:
			# Иначе выполняем стрельбу
			shoot()

func check_for_door() -> Node3D:
	# Используем RayCast3D для проверки, на что смотрит игрок
	hook_raycast.force_raycast_update()
	if hook_raycast.is_colliding():
		var collider = hook_raycast.get_collider()
		if collider and collider.is_in_group("door"):
			return collider.get_parent() # Возвращаем узел двери
	return null

func shoot() -> void:
	# Логика стрельбы
	shotgun.update_state("fire_sg")

func reset_jump_count() -> void:
	jump_count = 0
	air_dash_count = 0

# Обработка здоровья
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	print("Player died")
	queue_free()
