extends Node3D

var current_weapon: Node3D
var weapons: Array = []
var weapon_index: int = 0

func _ready() -> void:
	# Инициализация оружия
	weapons = [$WeaponRoot/Shotgun, $WeaponRoot/Pistols]
	for weapon in weapons:
		weapon.visible = false
		weapon.set_process(false)
	switch_weapon(0)

func switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if current_weapon:
		current_weapon.visible = false
		current_weapon.set_process(false)
	current_weapon = weapons[index]
	current_weapon.visible = true
	current_weapon.set_process(true)
	weapon_index = index

func _input(event: InputEvent) -> void:
	# Переключение оружия по клавише (например, Q)
	if event.is_action_pressed("switch_weapon"):
		var next_index = (weapon_index + 1) % weapons.size()
		switch_weapon(next_index)
