extends Node2D

@onready var player = $Player
@onready var enemy_spawner = $EnemySpawner
@onready var block_layer = $BlockLayer
@onready var grid_overlay = $GridOverlay
# @onready var upgrade_ui = $UpgradePhaseUI  # COMMENT OUT

const BLOCK_TILE_SOURCE_ID = 0
const BLOCK_TILE_ATLAS_COORDS = Vector2i(3, 4)
const GRID_TO_TILEMAP_OFFSET = Vector2i(-14, -7)
const TILES_PER_GRID_CELL = 1

var current_wave = 0
var current_room = 0
var enemies_alive = 0
var wave_active = false
var available_upgrades: Array[UpgradeItem] = []

func _ready():
	grid_overlay.upgrade_placed.connect(_on_upgrade_placed)
	# upgrade_ui.confirmed.connect(_on_upgrade_confirmed)  # COMMENT OUT
	# upgrade_ui.skipped.connect(_on_upgrade_skipped)  # COMMENT OUT
	
	print("=== GAME START ===")
	
	await get_tree().create_timer(1.0).timeout
	start_wave()

func start_wave():
	current_wave += 1
	wave_active = true
	enemies_alive = 0
	
	print("\n=== WAVE ", current_wave, " - ROOM ", current_room, " ===")
	
	# Hide grid
	grid_overlay.hide_grid()
	
	# Enable gameplay
	player.set_physics_process(true)
	
	spawn_wave_enemies()

func spawn_wave_enemies():
	var enemy_count = 3 + (current_wave - 1) * 2
	print("Spawning ", enemy_count, " enemies...")
	
	for i in enemy_count:
		await get_tree().create_timer(0.3).timeout
		spawn_single_enemy()

func spawn_single_enemy():
	var enemy = enemy_spawner.spawn_enemy()
	if enemy:
		enemies_alive += 1
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Remaining: ", enemies_alive)
	
	if enemies_alive <= 0 and wave_active:
		wave_complete()

func wave_complete():
	wave_active = false
	print("\n=== WAVE COMPLETE ===")
	
	current_room += 1
	
	await get_tree().create_timer(1.5).timeout
	enter_upgrade_phase()

func enter_upgrade_phase():
	print("\n=== UPGRADE PHASE - ROOM ", current_room, " ===")
	print("Press 1, 2, 3 to drag upgrades")
	print("Press SPACE to continue to next wave")
	
	# Pause gameplay
	player.set_physics_process(false)
	
	# Show grid
	grid_overlay.show_grid()
	
	# Add test upgrades
	available_upgrades.clear()
	available_upgrades.append(create_upgrade("2x1", [Vector2i(0,0), Vector2i(1,0)]))
	available_upgrades.append(create_upgrade("L-Shape", [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1)]))
	available_upgrades.append(create_upgrade("2x2", [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]))

func create_upgrade(upgrade_name: String, shape: Array[Vector2i]) -> UpgradeItem:
	var upgrade = UpgradeItem.new()
	upgrade.upgrade_name = upgrade_name  # Changed from 'name'
	upgrade.grid_shape = shape
	upgrade.tile_pattern = []
	for i in shape.size():
		upgrade.tile_pattern.append(BLOCK_TILE_ATLAS_COORDS)
	return upgrade

func _on_upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("Upgrade placed at grid: ", grid_pos)
	apply_upgrade_to_tilemap(upgrade, grid_pos)
	available_upgrades.erase(upgrade)

func apply_upgrade_to_tilemap(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("\n=== APPLYING UPGRADE ===")
	print("Grid position: ", grid_pos)
	
	for i in range(upgrade.grid_shape.size()):
		var offset = upgrade.grid_shape[i]
		var cell_grid_pos = grid_pos + offset
		
		# Direct 1:1 mapping - grid cell = tilemap tile
		var tile_pos = GRID_TO_TILEMAP_OFFSET + cell_grid_pos
		
		print("  Grid ", cell_grid_pos, " → Tile ", tile_pos)
		
		block_layer.set_cell(0, tile_pos, 0, Vector2i(3, 4))
	
	block_layer.force_update()
	print("=== APPLIED ===\n")						

# Manual control for testing
func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE
		if not wave_active:
			print("Starting next wave...")
			start_wave()
	
	# Number keys to drag upgrades
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 and available_upgrades.size() > 0:
			grid_overlay.start_drag(available_upgrades[0])
		elif event.keycode == KEY_2 and available_upgrades.size() > 1:
			grid_overlay.start_drag(available_upgrades[1])
		elif event.keycode == KEY_3 and available_upgrades.size() > 2:
			grid_overlay.start_drag(available_upgrades[2])
