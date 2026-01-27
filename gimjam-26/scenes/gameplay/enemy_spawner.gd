extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var max_enemies: int = 5
# Spawn area - adjust koordinat sesuai arena
@export var spawn_area_min: Vector2 = Vector2(80, 50)
@export var spawn_area_max: Vector2 = Vector2(760, 560)

enum SpawnSide {LEFT, RIGHT, TOP, BOTTOM, RANDOM}
@export var spawn_from_sides: Array[SpawnSide] = [SpawnSide.LEFT, SpawnSide.RIGHT, SpawnSide.TOP, SpawnSide.BOTTOM]

var spawn_timer: float = 0.0
var current_enemies: int = 0

func _ready():
	spawn_timer = spawn_interval

func _process(delta):
	spawn_timer -= delta
	
	if spawn_timer <= 0 and current_enemies < max_enemies:
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
		return
	
	var enemy = enemy_scene.instantiate()
	enemy.position = get_random_spawn_position()
	
	get_parent().add_child(enemy)
	current_enemies += 1
	
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died():
	current_enemies -= 1
