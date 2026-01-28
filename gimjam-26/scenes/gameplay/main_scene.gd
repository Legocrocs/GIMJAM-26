# main_scene.gd
extends Node2D

@onready var player = $Player
@onready var upgrade_screen = $UpgradeScreen
@onready var tilemap = $Foreground
@onready var enemy_spawner = $EnemySpawner

const BLOCK_TILE_SOURCE_ID = 0
const BLOCK_TILE_ATLAS_COORDS = Vector2i(0, 3)
const GRID_OFFSET = Vector2i(5, 3)
const TILES_PER_GRID_CELL = 1

var current_wave = 0
var current_room = 0
var enemies_alive = 0
var wave_active = false
var all_placed_blocks: Array[Vector2i] = [] 

func _ready():
	upgrade_screen.upgrades_confirmed.connect(_on_upgrades_confirmed)
	upgrade_screen.skip_upgrades.connect(_on_skip_upgrades)  # NEW
	upgrade_screen.hide()
	
	print("Main scene ready!")
	
	await get_tree().create_timer(1.0).timeout
	start_wave()

func _on_upgrades_confirmed():
	print("Upgrades confirmed!")
	upgrade_screen.hide()
	
	apply_grid_blocks()
	
	get_tree().paused = false
	start_wave()

# NEW: Skip upgrades and continue
func _on_skip_upgrades():
	print("Skipped upgrades, starting next wave...")
	upgrade_screen.hide()
	
	get_tree().paused = false
	start_wave()

func start_wave():
	current_wave += 1
	wave_active = true
	enemies_alive = 0
	
	print("=== WAVE ", current_wave, " START ===")
	
	# Re-apply all blocks to make sure they stay
	reapply_all_blocks()
	
	spawn_wave_enemies()
	
func spawn_wave_enemies():
	# Adjust difficulty based on wave
	var enemy_count = 3 + (current_wave * 2)  # More enemies each wave
	
	for i in enemy_count:
		spawn_enemy()

func spawn_enemy():
	# Use your enemy spawner or manual spawn
	enemy_spawner.spawn_enemy()
	enemies_alive += 1

func on_enemy_died():
	enemies_alive -= 1
	
	print("Enemy died! Remaining: ", enemies_alive)
	
	if enemies_alive <= 0 and wave_active:
		wave_complete()

func wave_complete():
	wave_active = false
	
	print("=== WAVE ", current_wave, " COMPLETE ===")
	
	# Move to next room (or show transition)
	move_to_next_room()

func move_to_next_room():
	current_room += 1
	
	print("Moving to room ", current_room, "...")
	
	# Optional: fade out/in, camera transition, etc
	await get_tree().create_timer(0.5).timeout
	
	# Show upgrade screen
	show_upgrade_screen()

func show_upgrade_screen():
	get_tree().paused = true
	upgrade_screen.show()

func apply_grid_blocks():
	var new_blocks = GridManager.get_blocked_cells()
	
	print("Applying ", new_blocks.size(), " NEW blocks...")
	print("Total blocks so far: ", all_placed_blocks.size())
	
	for grid_cell in new_blocks:
		# Skip if already placed
		if grid_cell in all_placed_blocks:
			continue
		
		var tile_pos = GRID_OFFSET + grid_cell
		tilemap.set_cell(0, tile_pos, BLOCK_TILE_SOURCE_ID, BLOCK_TILE_ATLAS_COORDS)
		
		# Add to persistent list
		all_placed_blocks.append(grid_cell)
		
		print("  Placed block at grid ", grid_cell, " (tilemap ", tile_pos, ")")

func reapply_all_blocks():
	# Re-apply ALL blocks (call this after wave starts)
	print("Re-applying all ", all_placed_blocks.size(), " blocks...")
	
	for grid_cell in all_placed_blocks:
		var tile_pos = GRID_OFFSET + grid_cell
		tilemap.set_cell(0, tile_pos, BLOCK_TILE_SOURCE_ID, BLOCK_TILE_ATLAS_COORDS)

# Connect enemy deaths
func _on_enemy_died():
	on_enemy_died()
