extends Node2D

# --- STATE MANAGEMENT ---
enum GameState { PLAYING, BUILDING }
var current_state = GameState.PLAYING

# --- REFERENCES ---
# Adjust these paths if your UI is structured differently (e.g. direct children vs CanvasLayer)
@onready var grid_overlay = $GridOverlay
@onready var block_inventory = $UI/PlayerInventory/TextureRect/Control/InventorySlots
@onready var block_layer = $BlockLayer # The TileMap or Node2D holding your blocks
@onready var player = $Player

# --- CONFIGURATION ---
@export_group("Drops")
@export var world_item_scene: PackedScene # Drag 'WorldItem.tscn' here
@export var possible_drops: Array[UpgradeItem] = [] # Drag 'block_square.tres', etc. here

# --- CONSTANTS ---
const BLOCK_TILE_SOURCE_ID = 0
const BLOCK_TILE_ATLAS_COORDS = Vector2i(3, 4) 
const GRID_TO_TILEMAP_OFFSET = Vector2i(-11, -5)

func _ready():
	# Connect the Grid Overlay signal
	if grid_overlay:
		grid_overlay.upgrade_placed.connect(_on_upgrade_placed)
	
	# Ensure Build Mode is hidden at start
	toggle_build_mode(false)
	
	print("=== Main Scene Initialized (Grid Mode Ready) ===")

func _input(event):
	# 1. TOGGLE BUILD MODE (Tab)
	if event.is_action_pressed("toggle_build"): # Map 'TAB' in Project Settings
		var new_state = not grid_overlay.visible
		toggle_build_mode(new_state)

	# 2. DEBUG HELPER: Spawn Random Block (Press 'P')
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		print("Debug: Spawning random block...")
		spawn_block_drop()

# --- MODE SWITCHING ---
func toggle_build_mode(enabled: bool):
	if enabled:
		current_state = GameState.BUILDING
		
		if grid_overlay: grid_overlay.show_grid()
		if block_inventory: block_inventory.visible = true
		
		# Optional: Stop player movement while building
		if player: player.set_physics_process(false)
		
	else:
		current_state = GameState.PLAYING
		
		if grid_overlay: grid_overlay.hide_grid()
		if block_inventory: block_inventory.visible = false
		
		if player: player.set_physics_process(true)

# --- ITEM DROPPING LOGIC ---
func spawn_block_drop():
	# Safety Checks
	if not world_item_scene:
		print("Error: 'world_item_scene' is missing in MainScene Inspector!")
		return
	if possible_drops.is_empty():
		print("Error: 'possible_drops' array is empty in MainScene Inspector!")
		return

	# 1. Instantiate
	var drop = world_item_scene.instantiate()
	
	# 2. Position (Near player with slight random offset)
	var spawn_pos = player.global_position if player else Vector2(100, 100)
	var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
	drop.global_position = spawn_pos + offset
	
	# 3. Add to Scene
	get_tree().current_scene.call_deferred("add_child", drop)
	
	# 4. Inject Data
	# We wait for the node to enter tree to ensure children (TextureButton) are ready
	await drop.ready 
	
	var random_block = possible_drops.pick_random()
	
	# Use the robust finding method we discussed earlier
	var button = drop.get_node_or_null("TextureButton")
	if button and button.has_method("set_item"):
		button.set_item(random_block)
		print("Dropped: ", random_block.upgrade_name)
	else:
		print("Error: Could not find 'TextureButton' on dropped item.")

# --- GRID PLACEMENT CALLBACKS ---
func _on_upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i):
	print("Grid Overlay reported placement at: ", grid_pos)
	apply_upgrade_to_tilemap(upgrade, grid_pos)

func apply_upgrade_to_tilemap(upgrade: UpgradeItem, grid_pos: Vector2i):
	# Paint every cell defined in the block's shape
	for i in range(upgrade.grid_shape.size()):
		var offset = upgrade.grid_shape[i]
		var cell_grid_pos = grid_pos + offset
		
		# Convert Grid Coords -> TileMap Coords
		var tile_pos = GRID_TO_TILEMAP_OFFSET + cell_grid_pos
		
		# Determine Tile Texture (Pattern vs Default)
		var tile_atlas_coords = BLOCK_TILE_ATLAS_COORDS
		if i < upgrade.tile_pattern.size():
			tile_atlas_coords = upgrade.tile_pattern[i]
		
		# 1. Set the visual Tile
		if block_layer:
			# Note: If using TileMapLayer (Godot 4.3+), use set_cell directly.
			# If using legacy TileMap, ensure 'layer 0' is correct.
			block_layer.set_cell(tile_pos, BLOCK_TILE_SOURCE_ID, tile_atlas_coords)
			
			# 2. Add physical Collision
			create_tile_collision(tile_pos)

func create_tile_collision(tile_pos: Vector2i):
	if not block_layer: return

	# Create a static body for the wall
	var body = StaticBody2D.new()
	body.collision_layer = 1 # Adjust to match your Wall layer
	body.name = "BlockCol_" + str(tile_pos)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(16, 16) # Adjust this to your actual tile size
	shape.shape = rect
	
	body.add_child(shape)
	
	# Position correctly in world space
	var world_pos = block_layer.map_to_local(tile_pos)
	body.global_position = world_pos
	
	block_layer.add_child(body)
