extends Node3D

@export var splash_scene: PackedScene
@export var rain_area_min: Vector3 = Vector3(-10, 10, -10)
@export var rain_area_max: Vector3 = Vector3(10, 10, 10)
@export var rays_per_frame: int = 10
@export var ray_length: float = 20.0
@export var collision_mask: int = 1  # Слой для поверхностей

@onready var particles = $GPUParticles3D

func _process(_delta):
	for i in range(rays_per_frame):
		var x = randf_range(rain_area_min.x, rain_area_max.x)
		var z = randf_range(rain_area_min.z, rain_area_max.z)
		var origin = Vector3(x, rain_area_max.y, z)
		var direction = Vector3.DOWN
		var end = origin + direction * ray_length
		
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(origin, end, collision_mask)
		var result = space_state.intersect_ray(query)
		
		if result:
			var collision_position = result.position
			var normal = result.normal
			
			var splash = splash_scene.instantiate()
			add_child(splash)
			splash.global_position = collision_position
			
			var z_axis = -normal.normalized()
			var x_axis = Vector3.UP.cross(z_axis).normalized()
			if x_axis.length_squared() < 0.01:
				x_axis = Vector3.RIGHT.cross(z_axis).normalized()
			var y_axis = z_axis.cross(x_axis).normalized()
			splash.global_transform.basis = Basis(x_axis, y_axis, z_axis)
