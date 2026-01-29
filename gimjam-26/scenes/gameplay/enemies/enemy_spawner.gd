extends Node2D

# Drag your enemy_1.tscn from the FileSystem into this slot in the Inspector
@export var enemy_scene: PackedScene 
@export var spawn_time: float = 2.0

func _ready():
	spawn_timer()

func spawn_timer():
	while true:
		await get_tree().create_timer(spawn_time).timeout
		spawn_enemy()

func spawn_enemy():
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		
		enemy.global_position = global_position
		
		get_tree().current_scene.add_child(enemy)
