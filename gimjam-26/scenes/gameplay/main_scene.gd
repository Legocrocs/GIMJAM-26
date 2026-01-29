extends Node2D

@onready var player = $Player
@onready var enemy_spawner = $EnemySpawner
@onready var block_layer = $BlockLayer
@onready var grid_overlay = $GridOverlay

const BLOCK_TILE_SOURCE_ID = 0
const BLOCK_TILE_ATLAS_COORDS = Vector2i(3, 4) # Fallback tile
const GRID_TO_TILEMAP_OFFSET = Vector2i(-11, -5)

# --- GAME STATE MANAGEMENT ---
enum GameState { WAVE_ACTIVE, WAITING_FOR_UPGRADE, UPGRADE_PHASE }
var current_state = GameState.WAVE_ACTIVE
var is_spawning = false  # Locks the wave end while enemies are spawning
# -----------------------------

var current_wave = 0
var current_room = 0
var enemies_alive = 0

var available_upgrades: Array[UpgradeItem] = []

func _ready():
	grid_overlay.upgrade_placed.connect(_on_upgrade_placed)
	
	print("=== GAME START ===")
	
	# Small delay before first wave
	await get_tree().create_timer(1.0).timeout
	start_wave()

func start_wave():
	current_wave += 1
	current_state = GameState.WAVE_ACTIVE
	enemies_alive = 0
	
	print("\n=== WAVE ", current_wave, " - ROOM ", current_room, " ===")
	
	# Hide grid and Enable player
	grid_overlay.hide_grid()
	player.set_physics_process(true)
	
	spawn_wave_enemies()

func spawn_wave_enemies():
	var enemy_count = 3 + (current_wave - 1) * 2
	print("Spawning ", enemy_count, " enemies...")
	
	# LOCK: Prevent "Wave Complete" from triggering while we are still spawning
	is_spawning = true
	
	for i in enemy_count:
		await get_tree().create_timer(0.3).timeout
		spawn_single_enemy()
	
	# UNLOCK: Spawning finished
	is_spawning = false
	
	# Safety Check: If player killed enemies INSTANTLY as they spawned
	if enemies_alive == 0 and current_state == GameState.WAVE_ACTIVE:
		wave_complete()

func spawn_single_enemy():
	var enemy = enemy_spawner.spawn_enemy()
	if enemy:
		enemies_alive += 1
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Remaining: ", enemies_alive)
	
	# Only finish wave if: 
	# 1. No enemies left
	# 2. We are NOT currently spawning more
	# 3. The wave is actually active
	if enemies_alive <= 0 and not is_spawning and current_state == GameState.WAVE_ACTIVE:
		wave_complete()

func wave_complete():
	current_state = GameState.WAITING_FOR_UPGRADE
	print("\n=== WAVE COMPLETE ===")
	print(">> PRESS SPACE TO OPEN UPGRADE GRID <<")
	
	current_room += 1

func enter_upgrade_phase():
	current_state = GameState.UPGRADE_PHASE
	print("\n=== UPGRADE PHASE - ROOM ", current_room, " ===")
	print("Press 1, 2, 3 to drag upgrades")
	print("Press SPACE to start next wave")
	
	# Pause player
	player.set_physics_process(false)
	
	# Show grid
	grid_overlay.show_grid()
	
	add_test_upgrades()

func add_test_upgrades():
	available_upgrades.clear()
	
	# 3x1 Horizontal (Wood)
	available_upgrades.append(create_upgrade_with_pattern(
		"3x1",
		[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(3,6), Vector2i(4,6), Vector2i(5,6)]
	))
	
	# 1x3 Vertical (Wood)
	available_upgrades.append(create_upgrade_with_pattern(
		"1x3",
		[Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)],
		[Vector2i(6,4), Vector2i(6,5), Vector2i(6,6)]
	))
	
	# 2x2 Square (Light Wood)
	available_upgrades.append(create_upgrade_with_pattern(
		"2x2",
		[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
		[Vector2i(3,4), Vector2i(4,4), Vector2i(3,5), Vector2i(4,5)]
	))
	
	print("Added test upgrades")

func create_upgrade_with_pattern(upgrade_name: String, shape: Array[Vector2i], tile_coords: Array[Vector2i]) -> UpgradeItem:
	var upgrade = UpgradeItem.new()
	upgrade.upgrade_name = upgrade_name
	upgrade.grid_shape = shape
	upgrade.tile_pattern = [] 
	
	for coord in tile_coords:
		upgrade.tile_pattern.append(coord)
	
	return upgrade

func _on_upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("Upgrade placed at: ", grid_pos)
	apply_upgrade_to_tilemap(upgrade, grid_pos)
	available_upgrades.erase(upgrade)

func apply_upgrade_to_tilemap(upgrade: UpgradeItem, grid_pos: Vector2i):
	for i in range(upgrade.grid_shape.size()):
		var offset = upgrade.grid_shape[i]
		var cell_grid_pos = grid_pos + offset
		
		# Convert Grid Coords -> World Tile Coords
		var tile_pos = GRID_TO_TILEMAP_OFFSET + cell_grid_pos
		
		# Pick the specific tile texture for this part of the shape
		var tile_atlas_coords = BLOCK_TILE_ATLAS_COORDS
		if i < upgrade.tile_pattern.size():
			tile_atlas_coords = upgrade.tile_pattern[i]
		
		# Set Tile
		block_layer.set_cell(0, tile_pos, BLOCK_TILE_SOURCE_ID, tile_atlas_coords)
		
		# Add Collision
		create_tile_collision(tile_pos)
	
	block_layer.force_update()

func create_tile_collision(tile_pos: Vector2i):
	var body = StaticBody2D.new()
	body.collision_layer = 1
	body.name = "BlockCollision_" + str(tile_pos)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	
	body.add_child(shape)
	
	var world_pos = block_layer.map_to_local(tile_pos)
	body.global_position = world_pos
	block_layer.add_child(body)

# --- INPUT HANDLING ---
func _input(event):
	if event.is_action_pressed("ui_accept"): # SPACE BAR
		
		# Scenario A: Wave ended, waiting to open grid
		if current_state == GameState.WAITING_FOR_UPGRADE:
			enter_upgrade_phase()
			
		# Scenario B: In grid mode, ready to start next wave
		elif current_state == GameState.UPGRADE_PHASE:
			print("Starting next wave...")
			start_wave()
	
	# Number keys to drag upgrades (Only allowed in Upgrade Phase)
	if current_state == GameState.UPGRADE_PHASE and event is InputEventKey and event.pressed:
		if event.keycode == KEY_1 and available_upgrades.size() > 0:
			grid_overlay.start_drag(available_upgrades[0])
		elif event.keycode == KEY_2 and available_upgrades.size() > 1:
			grid_overlay.start_drag(available_upgrades[1])
		elif event.keycode == KEY_3 and available_upgrades.size() > 2:
			grid_overlay.start_drag(available_upgrades[2])
