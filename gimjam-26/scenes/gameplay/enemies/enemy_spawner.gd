extends Node2D

signal room_cleared

# Drag your enemy_1.tscn into this slot in the Inspector
@export var enemy_scene: PackedScene
@export var spawn_time: float = 2.0
@export var MaxEnemy: int

# IMPORTANT: default false so it NEVER spawns before ESC-unlock
@export var autostart: bool = false

var _running: bool = false
var _spawned_total: int = 0
var _alive: int = 0


func _ready() -> void:
	add_to_group("enemy_spawner")
	if autostart:
		start_spawning()


func start_spawning() -> void:
	if _running:
		return
	_running = true
	_spawn_loop()


func stop_spawning() -> void:
	_running = false


func reset_counts() -> void:
	_running = false
	_spawned_total = 0
	_alive = 0


func is_cleared() -> bool:
	# cleared means: finished spawning AND no alive enemies
	return (_spawned_total >= MaxEnemy) and (_alive <= 0)


func _spawn_loop() -> void:
	# run in background (async) without blocking caller
	await get_tree().process_frame

	while _running:
		# if already spawned enough, stop and wait for alive to reach 0
		if _spawned_total >= MaxEnemy:
			_running = false
			_check_cleared()
			return

		await get_tree().create_timer(spawn_time).timeout
		if not _running:
			return

		_spawn_enemy()


func _spawn_enemy() -> void:
	if enemy_scene == null:
		return

	var spawn_global := global_position

	var enemy := enemy_scene.instantiate()
	enemy.add_to_group("enemies") # optional but useful for cleanup

	# ✅ Put enemies in the SAME parent as Player (not under Background/map)
	var root_parent := get_tree().current_scene
	root_parent.add_child(enemy)

	# ✅ Set global position AFTER parenting
	enemy.global_position = spawn_global

	# ✅ Prevent inherited scaling surprises
	if enemy is Node2D:
		(enemy as Node2D).scale = Vector2.ONE

	_spawned_total += 1
	_alive += 1

	enemy.tree_exited.connect(_on_enemy_exited)
	_check_cleared()

func _on_enemy_exited() -> void:
	_alive = max(0, _alive - 1)
	_check_cleared()


func _check_cleared() -> void:
	if is_cleared():
		emit_signal("room_cleared")
