extends Node3D

@export var sway_sensitivity := 0.000055
@export var max_sway_angle := 5 # В градусах
@export var sway_smoothness := 3 # Чем больше, тем быстрее сглаживание
@export var sway_fall_multiplier := 0.005 # Множитель для sway при падении
@export var sway_jump_multiplier := 0.005 # Множитель для sway при подъеме
@export var sway_horizontal_multiplier := 0.1 # Множитель для sway при движении влево/вправ
@export var max_sway_distance_fall := 0.15 # Максимальное расстояние sway при падении
@export var max_sway_distance_jump := 0.2 # Максимальное расстояние sway при подъеме
@export var max_sway_distance_horizontal := 0.05 # Максимальное расстояние sway при движении влево/вправ
@export var recoil_distance := 0.15 # Расстояние отдачи
@export var recoil_speed := 5.0 # Скорость возвращения оружия в исходное положение

var target_position := Vector3.ZERO
var current_position := Vector3.ZERO
var velocity_reference: CharacterBody3D
var recoil_offset := Vector3.ZERO
var is_recoiling := false

func _ready() -> void:
	# Убедитесь, что node player существует
	velocity_reference = get_node("/root/Scene/player") as CharacterBody3D
	if not velocity_reference:
		print("Ошибка: Не найден узел player!")
		return

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or velocity_reference == null:
		return

	# Получаем скорость мыши (насколько она быстро двигается)
	var mouse_velocity := Input.get_last_mouse_velocity()

	# Вычисляем целевой наклон (для sway по горизонтали)
	target_position.y = clamp(mouse_velocity.y * sway_sensitivity, -deg_to_rad(max_sway_angle), deg_to_rad(max_sway_angle))
	target_position.x = clamp(-mouse_velocity.x * sway_sensitivity, -deg_to_rad(max_sway_angle), deg_to_rad(max_sway_angle))

	# Добавляем sway в зависимости от вертикальной скорости (падение или подъем)
	var vertical_speed = velocity_reference.velocity.y
	if vertical_speed < 0: # Падение
		target_position.y += sway_fall_multiplier * abs(vertical_speed)
		# Ограничиваем максимальное расстояние sway при падении
		target_position.y = clamp(target_position.y, -max_sway_distance_fall, max_sway_distance_fall)
	elif vertical_speed > 0: # Подъем
		target_position.y -= sway_jump_multiplier * abs(vertical_speed)
		# Ограничиваем максимальное расстояние sway при подъеме
		target_position.y = clamp(target_position.y, -max_sway_distance_jump, max_sway_distance_jump)

	# Добавляем sway в зависимости от горизонтальной скорости (движение влево/вправ)
	var horizontal_speed = velocity_reference.velocity.x
	if horizontal_speed != 0: # Движение влево/вправ
		# Изменение направления смещения (сделать противоположным движению игрока)
		target_position.x += -sway_horizontal_multiplier * horizontal_speed
		# Ограничиваем максимальное расстояние sway при движении влево/вправ
		target_position.x = clamp(target_position.x, -max_sway_distance_horizontal, max_sway_distance_horizontal)

	# Если происходит отдача, добавляем смещение
	if is_recoiling:
		target_position.z += recoil_offset.z
		# Плавно возвращаем оружие в исходное положение
		recoil_offset = recoil_offset.lerp(Vector3.ZERO, delta * recoil_speed)

	# Плавно интерполируем текущее положение к целевому
	current_position = current_position.lerp(target_position, delta * sway_smoothness)

	# Применяем к локальной позиции оружия (это движение по вертикали и горизонтали)
	position = current_position

# Функция для активации отдачи при выстреле
func apply_recoil() -> void:
	is_recoiling = true
	recoil_offset = Vector3(0, 0, recoil_distance) # Добавляем отдачу по оси Z (вектор по оси Z отвечает за движение назад)
