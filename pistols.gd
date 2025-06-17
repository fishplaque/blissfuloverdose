extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
var current_state: String = "idle"
var is_alt_mode: bool = false
var can_shoot_normal: bool = true
var can_shoot_alt: bool = true
var is_shooting_normal: bool = false
var normal_shoot_timer: float = 0.0
var alt_shoot_timer: float = 0.0
var last_shot: int = 1

# Параметры стрельбы
@export var damage_per_bullet: float = 20.0
@export var range_distance: float = 5000.0
@export var inaccuracy_degrees: float = 2.0
@export var force: float = 5.0

# Точки выстрела
@onready var muzzle_point_left = $Armature/Skeleton3D/Cube/MuzzlePositionLeft
@onready var muzzle_point_right = $Armature/Skeleton3D/Cube/MuzzlePositionRight
@onready var muzzle_point_middle1 = $Armature/Skeleton3D/Cube/MuzzlePositionMiddle1
@onready var muzzle_point_middle2 = $Armature/Skeleton3D/Cube/MuzzlePositionMiddle2

# Длительности анимаций
const RELEASE_DURATION: float = 0.15
const SHOT1_DURATION: float = 0.1
const SHOT2_DURATION: float = 0.1

# Задержки между выстрелами
const NORMAL_SHOOT_DELAY: float = 0.5
const ALT_SHOOT_DELAY: float = 1.5

func _ready() -> void:
	animation_tree.active = true
	update_state("idle")
	
	# Проверяем наличие точек выстрела
	if not muzzle_point_left:
		print("Ошибка: MuzzlePositionLeft не найден!")
	if not muzzle_point_right:
		print("Ошибка: MuzzlePositionRight не найден!")
	if not muzzle_point_middle1:
		print("Ошибка: MuzzlePositionMiddle1 не найден!")
	if not muzzle_point_middle2:
		print("Ошибка: MuzzlePositionMiddle2 не найден!")
	
	# Проверка длительностей анимаций
	if SHOT1_DURATION > NORMAL_SHOOT_DELAY or SHOT2_DURATION > NORMAL_SHOOT_DELAY:
		print("Предупреждение: Длительность анимации shot1 или shot2 больше, чем NORMAL_SHOOT_DELAY (0.5 сек).")
	if RELEASE_DURATION > ALT_SHOOT_DELAY:
		print("Предупреждение: Длительность анимации release больше, чем ALT_SHOOT_DELAY (3 сек).")

func _process(delta: float) -> void:
	# Обновление таймеров
	if normal_shoot_timer > 0:
		normal_shoot_timer -= delta
		if normal_shoot_timer <= 0:
			can_shoot_normal = true
	if alt_shoot_timer > 0:
		alt_shoot_timer -= delta
		if alt_shoot_timer <= 0:
			can_shoot_alt = true
	
	# Проверка альтернативного режима (ПКМ зажата)
	if Input.is_action_pressed("shoot_alt"):
		if not is_alt_mode:
			print("Активация альтернативного режима")
			is_alt_mode = true
			update_state("start")
		elif current_state not in ["start", "release"]:
			update_state("idle2")
	elif is_alt_mode:
		print("Деактивация альтернативного режима")
		is_alt_mode = false
		update_state("idle")
	
	# Обработка движения для анимации бега (только если не стреляем)
	var is_moving = Input.is_action_pressed("move_forward") or Input.is_action_pressed("move_backward") or \
					Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")
	if not Input.is_action_pressed("shoot") and not is_alt_mode:
		if is_moving and current_state != "run":
			update_state("run")
		elif not is_moving and current_state != "idle":
			update_state("idle")
	
	# Обработка стрельбы
	if is_alt_mode:
		if Input.is_action_pressed("shoot") and can_shoot_alt:
			print("Вызов shoot_alt() для release")
			shoot_alt()
	else:
		if Input.is_action_pressed("shoot") and can_shoot_normal and not is_shooting_normal:
			shoot_normal()

func shoot_normal() -> void:
	is_shooting_normal = true
	can_shoot_normal = false
	normal_shoot_timer = NORMAL_SHOOT_DELAY
	
	if last_shot == 1:
		update_state("shot1")
		fire_bullet(muzzle_point_left)
		await get_tree().create_timer(SHOT1_DURATION).timeout
		last_shot = 2
	else:
		update_state("shot2")
		fire_bullet(muzzle_point_right)
		await get_tree().create_timer(SHOT2_DURATION).timeout
		last_shot = 1
	
	if normal_shoot_timer > 0:
		await get_tree().create_timer(normal_shoot_timer).timeout
	
	is_shooting_normal = false
	if Input.is_action_pressed("shoot") and normal_shoot_timer <= 0:
		can_shoot_normal = true

func shoot_alt() -> void:
	can_shoot_alt = false
	alt_shoot_timer = ALT_SHOOT_DELAY
	if current_state != "idle2":
		update_state("idle2")
	update_state("release")
	fire_laser(muzzle_point_middle1)
	fire_laser(muzzle_point_middle2)
	await get_tree().create_timer(RELEASE_DURATION).timeout
	if is_alt_mode and Input.is_action_pressed("shoot") and alt_shoot_timer <= 0:
		can_shoot_alt = true

func fire_bullet(muzzle_point: Node3D) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("Ошибка: Камера не найдена!")
		return
	
	var viewport = get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_end = ray_origin + camera.project_ray_normal(screen_center) * range_distance
	
	var spread = create_random_spread(inaccuracy_degrees)
	var spread_direction = (ray_end - ray_origin).normalized() + spread
	spread_direction = spread_direction.normalized()
	
	if not muzzle_point:
		print("Ошибка: muzzle_point не найден!")
		return
	
	spawn_muzzle_flash(muzzle_point)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(muzzle_point.global_position, muzzle_point.global_position + spread_direction * range_distance)
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position") and result.has("normal"):
		spawn_hit_effect(result.position, result.normal)
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage_per_bullet)
		if result.collider is RigidBody3D:
			var impulse_pos = result.position - result.collider.global_position
			result.collider.apply_impulse(spread_direction * force, impulse_pos)
	else:
		print("Рейкаст не попал или результат некорректен: ", result)

func fire_laser(muzzle_point: Node3D) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("Ошибка: Камера не найдена!")
		return
	
	var direction = -camera.global_transform.basis.z.normalized()
	
	if not muzzle_point:
		print("Ошибка: muzzle_point не найден!")
		return
	
	spawn_muzzle_flash(muzzle_point)
	
	var laser = ImmediateMesh.new()
	laser.surface_begin(Mesh.PRIMITIVE_LINES)
	laser.surface_add_vertex(muzzle_point.global_position)
	laser.surface_add_vertex(muzzle_point.global_position + direction * range_distance)
	laser.surface_end()
	
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.emission = Color.WHITE
	material.emission_enabled = true
	laser.surface_set_material(0, material)
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = laser
	get_tree().current_scene.add_child(mesh_instance)
	
	var tween = create_tween()
	if tween:
		tween.tween_property(material, "albedo_color:a", 0.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(mesh_instance.queue_free)
	else:
		print("Ошибка: Не удалось создать Tween!")
		mesh_instance.queue_free()
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(muzzle_point.global_position, muzzle_point.global_position + direction * range_distance)
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF
	var result = space_state.intersect_ray(query)
	
	if result and result.has("position") and result.has("normal"):
		spawn_hit_effect(result.position, result.normal)
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage_per_bullet * 2)
		if result.collider is RigidBody3D:
			var impulse_pos = result.position - result.collider.global_position
			result.collider.apply_impulse(direction * force * 2, impulse_pos)

func spawn_muzzle_flash(muzzle_point: Node3D) -> void:
	var muzzle_flash = Sprite3D.new()
	muzzle_point.add_child(muzzle_flash)
	muzzle_flash.transform.origin = Vector3.ZERO
	
	var texture = load("res://MisarableOverdose/models_and_textures/MuzzleFlash.png")
	if texture:
		muzzle_flash.texture = texture
	else:
		print("Текстура muzzle_flash.png не найдена! Используется заглушка.")
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 0, 0.8))
		var texture_fallback = ImageTexture.create_from_image(image)
		muzzle_flash.texture = texture_fallback
	
	muzzle_flash.pixel_size = 0.01
	muzzle_flash.scale = Vector3(1, 1, 1)
	muzzle_flash.modulate = Color(1, 1, 1, 1)
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		muzzle_flash.look_at(camera.global_position, Vector3.UP)
	else:
		print("Камера не найдена, вспышка не ориентирована!")
	
	var tween = muzzle_flash.create_tween()
	if tween:
		tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.2)
		tween.tween_callback(muzzle_flash.queue_free)
	else:
		print("Ошибка: Не удалось создать Tween для muzzle flash!")
		muzzle_flash.queue_free()

func create_random_spread(degrees: float) -> Vector3:
	var rad = deg_to_rad(degrees)
	var rand_x = randf_range(-rad, rad)
	var rand_y = randf_range(-rad, rad)
	return Vector3(sin(rand_x), sin(rand_y), 0)

func spawn_hit_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	var hit_effect = Sprite3D.new()
	get_tree().current_scene.add_child(hit_effect)
	hit_effect.global_position = hit_position + hit_normal * 0.01
	
	var texture = load("res://MisarableOverdose/textures/349.png")
	if texture:
		hit_effect.texture = texture
	else:
		print("Текстура 349.png не найдена! Используется заглушка.")
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 0.5))
		var texture_fallback = ImageTexture.create_from_image(image)
		hit_effect.texture = texture_fallback
	
	hit_effect.pixel_size = 0.01
	hit_effect.scale = Vector3(0.5, 0.5, 0.5)
	hit_effect.modulate = Color(1, 1, 1, 1)
	
	var up_vector = Vector3.UP
	if abs(hit_normal.dot(Vector3.UP)) > 0.999:
		up_vector = Vector3.FORWARD
	
	if hit_normal.is_normalized():
		hit_effect.look_at(hit_position + hit_normal, up_vector)
		hit_effect.rotate_object_local(Vector3.RIGHT, deg_to_rad(0))
	else:
		print("Некорректная нормаль поверхности: ", hit_normal)
		hit_effect.look_at(hit_position + Vector3.FORWARD, Vector3.UP)
		hit_effect.rotate_object_local(Vector3.RIGHT, deg_to_rad(0))
	
	var tween = hit_effect.create_tween()
	if tween:
		tween.tween_property(hit_effect, "modulate:a", 0.0, 10)
		tween.tween_callback(hit_effect.queue_free)
	else:
		print("Ошибка: Не удалось создать Tween!")
		hit_effect.queue_free()

func update_state(state_name: String) -> void:
	if current_state != state_name:
		print("Переход к анимации: ", state_name)
		playback.travel(state_name)
		current_state = state_name
