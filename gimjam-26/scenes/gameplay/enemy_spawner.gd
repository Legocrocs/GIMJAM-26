# enemy_spawner.gd - SIMPLIFIED (no auto-spawn, no wave logic)
extends Node2D

@export var enemy_scene: PackedScene

# Spawn area
@export var spawn_area_min: Vector2 = Vector2(80, 50)
@export var spawn_area_max: Vector2 = Vector2(760, 560)

# Spawn sides
enum SpawnSide {LEFT, RIGHT, TOP, BOTTOM, RANDOM}
@export var spawn_from_sides: Array[SpawnSide] = [SpawnSide.LEFT, SpawnSide.RIGHT, SpawnSide.TOP, SpawnSide.BOTTOM]

func spawn_enemy():
	if enemy_scene == null:
		print("ERROR: Enemy scene not assigned!")
		return null
	
	var enemy = enemy_scene.instantiate()
	enemy.position = get_random_spawn_position()
	
	# Add to parent (MainScene)
	get_parent().add_child(enemy)
	
	return enemy  # Return for main_scene to handle

func get_random_spawn_position() -> Vector2:
	if spawn_from_sides.is_empty():
		return Vector2(400, 300)
	
	var side = spawn_from_sides.pick_random()
	var spawn_pos: Vector2
	
	match side:
		SpawnSide.LEFT:
			spawn_pos = Vector2(spawn_area_min.x, randf_range(spawn_area_min.y, spawn_area_max.y))
		SpawnSide.RIGHT:
			spawn_pos = Vector2(spawn_area_max.x, randf_range(spawn_area_min.y, spawn_area_max.y))
		SpawnSide.TOP:
			spawn_pos = Vector2(randf_range(spawn_area_min.x, spawn_area_max.x), spawn_area_min.y)
		SpawnSide.BOTTOM:
			spawn_pos = Vector2(randf_range(spawn_area_min.x, spawn_area_max.x), spawn_area_max.y)
		SpawnSide.RANDOM:
			spawn_pos = Vector2(randf_range(spawn_area_min.x, spawn_area_max.x), randf_range(spawn_area_min.y, spawn_area_max.y))
	
	return spawn_pos
