extends Node2D

signal wave_completed  # Signal untuk kasih tau wave selesai

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var enemies_per_wave: int = 5

# Spawn area
@export var spawn_area_min: Vector2 = Vector2(80, 50)
@export var spawn_area_max: Vector2 = Vector2(760, 560)

# Spawn sides
enum SpawnSide {LEFT, RIGHT, TOP, BOTTOM, RANDOM}
@export var spawn_from_sides: Array[SpawnSide] = [SpawnSide.LEFT, SpawnSide.RIGHT, SpawnSide.TOP, SpawnSide.BOTTOM]

var spawn_timer: float = 0.0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var wave_active: bool = false

func _ready():
	spawn_timer = spawn_interval

func start_wave():
	wave_active = true
	enemies_spawned = 0
	enemies_alive = 0
	print("Wave started! Kill %d enemies" % enemies_per_wave)

func _process(delta):
	if not wave_active:
		return
	
	spawn_timer -= delta
	
	if spawn_timer <= 0 and enemies_spawned < enemies_per_wave:
		spawn_enemy()
		spawn_timer = spawn_interval

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

func spawn_enemy():
	if enemy_scene == null:
		print("Error: Enemy scene not assigned!")
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.position = get_random_spawn_position()
	
	get_parent().add_child(enemy)
	
	# DEBUG
	print("Enemy spawned, connecting death signal...")
	
	# Connect death signal
	if enemy.has_signal("enemy_died"):
		var main_scene = get_tree().get_root().get_node("MainScene")  # Adjust path!
		
		if main_scene:
			enemy.enemy_died.connect(main_scene._on_enemy_died)
			print("  - Connected to main_scene")
		else:
			print("  - ERROR: MainScene not found!")
	else:
		print("  - ERROR: enemy_died signal not found!")

func _on_enemy_died():
	enemies_alive -= 1
	
	# mati checck
	if enemies_alive <= 0 and enemies_spawned >= enemies_per_wave:
		wave_completed.emit()
		wave_active = false
		print("Wave completed! Door unlocked!")

func get_enemy_count() -> String:
	return "%d/%d" % [enemies_alive, enemies_per_wave]
