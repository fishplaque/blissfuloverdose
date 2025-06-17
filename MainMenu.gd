extends Control

@export var test_map_path: String = "res://TestMap.tscn" # Путь к тестовой карте
@export var infinite_mode_path: String = "res://InfiniteMode.tscn" # Путь к сцене бесконечного режима

func _ready() -> void:
	# Подключаем сигналы кнопок
	$TestButton.pressed.connect(_on_test_button_pressed)
	$InfiniteButton.pressed.connect(_on_infinite_button_pressed)

func _on_test_button_pressed() -> void:
	# Переход на тестовую карту
	get_tree().change_scene_to_file(test_map_path)

func _on_infinite_button_pressed() -> void:
	# Переход на бесконечный режим
	get_tree().change_scene_to_file(infinite_mode_path)
