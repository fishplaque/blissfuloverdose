extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
var current_state: String = "idle_sg"
var is_shooting: bool = false
@export var povorot_sg_speed: float = 1.0  # Скорость анимации поворота

# Параметры дробовика
@export var pellet_count: int = 8  # Количество дробинок в выстреле
@export var spread_degrees: float = 15.0  # Разброс выстрела в градусах
@export var damage_per_pellet: float = 10.0  # Урон от одной дробинки
@export var range_distance: float = 50.0  # Дальность стрельбы
@export var force: float = 10.0  # Сила отдачи

# Таймер между выстрелами
var can_shoot: bool = true
var cooldown_time: float = 0.8  # Время между выстрелами в секундах

# Нода для позиции выстрела
@onready var muzzle_point = $Armature/Skeleton3D/Cube_001/MuzzlePosition
# Эффект выстрела
@onready var muzzle_flash = $Armature/Skeleton3D/Cube_001/MuzzlePosition/MuzzleFlash

func _ready() -> void:
	animation_tree.active = true
	update_state("idle_sg")
	
	# Настраиваем эффект выстрела
	setup_muzzle_flash()
	
	# Скрываем вспышку выстрела по умолчанию
	if muzzle_flash:
		muzzle_flash.visible = false
	else:
		print("Ошибка: MuzzleFlash не найден!")
	
	# Проверяем наличие muzzle_point
	if not muzzle_point:
		print("Ошибка: MuzzlePosition не найден!")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and not is_shooting and can_shoot:
		shoot()

func shoot() -> void:
	is_shooting = true
	can_shoot = false
	
	update_state("shoot_sg")
	fire_shotgun()
	
	if muzzle_flash:
		muzzle_flash.visible = true
		await get_tree().create_timer(0.1).timeout
		muzzle_flash.visible = false
	
	await get_tree().create_timer(0.35).timeout
	update_state("idle_sg")
	is_shooting = false
	
	await get_tree().create_timer(cooldown_time).timeout
	can_shoot = true

func fire_shotgun() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		print("Ошибка: Камера не найдена!")
		return
	
	var viewport = get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_end = ray_origin + camera.project_ray_normal(screen_center) * range_distance
	
	for i in range(pellet_count):
		var spread = create_random_spread(spread_degrees)
		var spread_direction = (ray_end - ray_origin).normalized() + spread
		spread_direction = spread_direction.normalized()
		
		if not muzzle_point:
			print("Ошибка: muzzle_point не найден!")
			return
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(muzzle_point.global_position, muzzle_point.global_position + spread_direction * range_distance)
		query.collide_with_areas = true
		query.collision_mask = 0xFFFFFFFF
		var result = space_state.intersect_ray(query)
		
		if result and result.has("position") and result.has("normal"):
			spawn_hit_effect(result.position, result.normal)
			if result.collider.has_method("take_damage"):
				result.collider.take_damage(damage_per_pellet)
			if result.collider is RigidBody3D:
				var impulse_pos = result.position - result.collider.global_position
				result.collider.apply_impulse(spread_direction * force, impulse_pos)
		else:
			print("Рейкаст не попал или результат некорректен: ", result)

func create_random_spread(degrees: float) -> Vector3:
	var rad = deg_to_rad(degrees)
	var rand_x = randf_range(-rad, rad)
	var rand_y = randf_range(-rad, rad)
	return Vector3(sin(rand_x), sin(rand_y), 0)

func spawn_hit_effect(hit_position: Vector3, hit_normal: Vector3) -> void:
	var hit_effect = Sprite3D.new()
	# Сначала добавляем узел в дерево сцены
	get_tree().current_scene.add_child(hit_effect)
	# Теперь можно безопасно устанавливать global_position
	hit_effect.global_position = hit_position + hit_normal * 0.01
	
	var texture = load("res://MisarableOverdose/textures/349.png")
	if texture:
		hit_effect.texture = texture
	else:
		print("Текстура hit_effect.png не найдена! Используется заглушка.")
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 0.5))
		var texture_fallback = ImageTexture.create_from_image(image)
		hit_effect.texture = texture_fallback
	
	hit_effect.pixel_size = 0.01
	hit_effect.scale = Vector3(0.5, 0.5, 0.5)
	hit_effect.modulate = Color(1, 1, 1, 1)
	
	# Проверяем, не коллинеарны ли нормаль и Vector3.UP
	var up_vector = Vector3.UP
	if abs(hit_normal.dot(Vector3.UP)) > 0.999:  # Если нормаль почти параллельна Vector3.UP
		up_vector = Vector3.FORWARD  # Используем альтернативный вектор "вверх"
	
	if hit_normal.is_normalized():
		hit_effect.look_at(hit_position + hit_normal, up_vector)
		hit_effect.rotate_object_local(Vector3.RIGHT, deg_to_rad(0))  # Исправлено: поворот на -90 градусов
	else:
		print("Некорректная нормаль поверхности: ", hit_normal)
		hit_effect.look_at(hit_position + Vector3.FORWARD, Vector3.UP)
		hit_effect.rotate_object_local(Vector3.RIGHT, deg_to_rad(0))  # Исправлено: поворот на -90 градусов
	
	var tween = hit_effect.create_tween()
	if tween:
		tween.tween_property(hit_effect, "modulate:a", 0.0, 10)
		tween.tween_callback(hit_effect.queue_free)
	else:
		print("Ошибка: Не удалось создать Tween!")
		hit_effect.queue_free()

func setup_muzzle_flash() -> void:
	if not has_node("Armature/Skeleton3D/Cube_001/MuzzlePosition/MuzzleFlash"):
		var flash = Sprite3D.new()
		flash.name = "MuzzleFlash"
		muzzle_point.add_child(flash)
		flash.billboard = true
		flash.pixel_size = 0.01
		flash.modulate = Color(1, 0.8, 0, 1)
		var texture = load("res://MisarableOverdose/models_and_textures/MuzzleFlash.png")
		if texture:
			flash.texture = texture
		else:
			print("Текстура вспышки не найдена!")

func update_state(state_name: String) -> void:
	if current_state != state_name:
		if state_name == "povorot_sg":
			var animation_node = animation_tree.get("parameters/animations/povorot_sg") as AnimationNodeAnimation
			if animation_node:
				animation_node.speed_scale = povorot_sg_speed
		else:
			var animation_node = animation_tree.get("parameters/animations/povorot_sg") as AnimationNodeAnimation
			if animation_node:
				animation_node.speed_scale = 0.3
		playback.travel(state_name)
		current_state = state_name
