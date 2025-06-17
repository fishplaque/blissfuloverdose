extends CharacterBody3D

@export var health: float = 200.0

func take_damage(amount: float) -> void:
	health -= amount
	print("Мишень получила урон. Осталось HP: ", health)

	if health <= 0:
		die()

func die() -> void:
	print("Мишень уничтожена!")
	queue_free()
