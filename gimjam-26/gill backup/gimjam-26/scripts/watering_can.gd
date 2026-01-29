extends WeaponData
class_name WateringCanWeapon

func activate(root_node: Node, origin: Vector2, direction: Vector2):
	for i in range(projectile_per_shot):
		var angle_offset = deg_to_rad(randf_range(-spread, spread))
		var new_dir = direction.rotated(angle_offset)
		
		# Reuse the helper from the parent class
		spawn_projectile(root_node, origin, new_dir)
