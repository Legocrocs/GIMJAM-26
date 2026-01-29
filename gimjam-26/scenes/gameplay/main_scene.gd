# main_scene.gd - FULL VERSION WITH TILE PATTERNS
extends Node2D

@onready var player = $Player
@onready var enemy_spawner = $EnemySpawner
@onready var block_layer = $BlockLayer
@onready var grid_overlay = $GridOverlay

const BLOCK_TILE_SOURCE_ID = 0
const BLOCK_TILE_ATLAS_COORDS = Vector2i(3, 4)  # Default fallback
const GRID_TO_TILEMAP_OFFSET = Vector2i(-11, -5)
const TILES_PER_GRID_CELL = 1

var current_wave = 0
var current_room = 0
var enemies_alive = 0
var wave_active = false
var available_upgrades: Array[UpgradeItem] = []

func _ready():
	grid_overlay.upgrade_placed.connect(_on_upgrade_placed)
	
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
	
	# Add test upgrades with specific tile patterns
	add_test_upgrades()

func add_test_upgrades():
	available_upgrades.clear()
	
	# 3x1 horizontal bar
	var upgrade_3x1 = create_upgrade_with_pattern(
		"3x1",
		[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(3,6), Vector2i(4,6), Vector2i(5,6)]
	)
	
	# 1x3 vertical bar
	var upgrade_1x3 = create_upgrade_with_pattern(
		"1x3",
		[Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)],
		[Vector2i(6,4), Vector2i(6,5), Vector2i(6,6)]
	)
	
	# 2x2 square
	var upgrade_2x2 = create_upgrade_with_pattern(
		"2x2",
		[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
		[Vector2i(3,4), Vector2i(4,4), Vector2i(3,5), Vector2i(4,5)]
	)
	
	available_upgrades.append(upgrade_3x1)
	available_upgrades.append(upgrade_1x3)
	available_upgrades.append(upgrade_2x2)
	
	print("Added ", available_upgrades.size(), " upgrades with tile patterns")

func create_upgrade_with_pattern(upgrade_name: String, shape: Array[Vector2i], tile_coords: Array[Vector2i]) -> UpgradeItem:
	var upgrade = UpgradeItem.new()
	upgrade.upgrade_name = upgrade_name
	upgrade.grid_shape = shape
	upgrade.tile_pattern = []
	
	# Add each tile coordinate
	for coord in tile_coords:
		upgrade.tile_pattern.append(coord)
	
	# Verify sizes match
	if upgrade.tile_pattern.size() != upgrade.grid_shape.size():
		print("WARNING: ", upgrade_name, " tile_pattern size (", upgrade.tile_pattern.size(), 
			  ") doesn't match grid_shape size (", upgrade.grid_shape.size(), ")")
	
	print("Created upgrade: ", upgrade_name, " with ", upgrade.tile_pattern.size(), " tiles")
	
	return upgrade

func _on_upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("\n=== UPGRADE PLACED ===")
	print("Upgrade: ", upgrade.upgrade_name)
	print("Grid position: ", grid_pos)
	
	apply_upgrade_to_tilemap(upgrade, grid_pos)
	available_upgrades.erase(upgrade)

func apply_upgrade_to_tilemap(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("=== APPLYING TO TILEMAP ===")
	
	# Apply each cell with its specific tile texture
	for i in range(upgrade.grid_shape.size()):
		var offset = upgrade.grid_shape[i]
		var cell_grid_pos = grid_pos + offset
		var tile_pos = GRID_TO_TILEMAP_OFFSET + cell_grid_pos
		
		# Get specific tile atlas coords for this cell
		var tile_atlas_coords = BLOCK_TILE_ATLAS_COORDS  # Fallback
		if i < upgrade.tile_pattern.size():
			tile_atlas_coords = upgrade.tile_pattern[i]
		
		print("  Cell ", i, ": Grid ", cell_grid_pos, " → Tile ", tile_pos, " → Atlas ", tile_atlas_coords)
		
		# Place tile with specific texture
		block_layer.set_cell(0, tile_pos, BLOCK_TILE_SOURCE_ID, tile_atlas_coords)
		
		# Add collision
		create_tile_collision(tile_pos)
	
	block_layer.force_update()
	print("=== TILEMAP UPDATED ===\n")

func create_tile_collision(tile_pos: Vector2i):
	# Create collision body for this tile
	var body = StaticBody2D.new()
	body.collision_layer = 1  # Layer 1 (walls)
	body.collision_mask = 0
	body.name = "BlockCollision_" + str(tile_pos)
	
	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(8, 8)  # Tile size
	collision_shape.shape = rect_shape
	
	body.add_child(collision_shape)
	
	# Position at tile world position
	var world_pos = block_layer.map_to_local(tile_pos)
	body.global_position = world_pos
	
	# Add to BlockLayer
	block_layer.add_child(body)

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
