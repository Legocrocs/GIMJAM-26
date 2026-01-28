extends Node2D

@onready var player = $Player
@onready var upgrade_screen = $UpgradeScreen
@onready var enemy_spawner = $EnemySpawner

const GRID_SIZE = Vector2i(10, 8)
const CELL_SIZE = 64

var current_wave = 0
var enemies_alive = 0
var wave_active = false

# Grid overlay
var grid_overlay: Control = null
var grid_cells: Array = []
var tile_texture_cache: Dictionary = {}
var debug_label: Label = null

# Tileset for blocks
@export var tileset: TileSet
@export var source_id: int = 0
@export var block_tile_coords: Vector2i = Vector2i(0, 3)

func _ready():
	upgrade_screen.upgrades_confirmed.connect(_on_upgrades_confirmed)
	upgrade_screen.skip_upgrades.connect(_on_skip_upgrades)
	upgrade_screen.hide()
	
	# Create debug label
	create_debug_label()
	
	# Create grid overlay
	create_grid_overlay()
	
	print("=== MAIN SCENE READY ===")
	print("Hold SHIFT to see mouse coords")
	print("Click to print exact position")
	print("Press BACKSPACE to test first 10 cells")
	print("========================")
	
	await get_tree().create_timer(1.0).timeout
	start_wave()

func create_debug_label():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "DebugCanvas"
	add_child(canvas)
	
	debug_label = Label.new()
	debug_label.position = Vector2(10, 10)
	debug_label.add_theme_font_size_override("font_size", 24)
	debug_label.add_theme_color_override("font_color", Color.YELLOW)
	debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	debug_label.add_theme_constant_override("outline_size", 2)
	canvas.add_child(debug_label)

func _process(_delta):
	if debug_label:
		var mouse_pos = get_viewport().get_mouse_position()
		
		if Input.is_key_pressed(KEY_SHIFT):
			debug_label.text = "Mouse: (%.0f, %.0f)" % [mouse_pos.x, mouse_pos.y]
			debug_label.visible = true
		else:
			debug_label.visible = false

func create_grid_overlay():
	# Create CanvasLayer for UI overlay
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GridOverlay"
	canvas_layer.layer = 1
	add_child(canvas_layer)
	
	# Create container
	grid_overlay = Control.new()
	grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(grid_overlay)
	
	# ADJUST THIS - Position grid overlay to match arena
	var grid_screen_pos = Vector2(155, 115) 
	
	# Create GridContainer
	var grid_container = GridContainer.new()
	grid_container.columns = GRID_SIZE.x
	grid_container.position = grid_screen_pos
	grid_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_overlay.add_child(grid_container)
	
	# Load tile texture
	var block_texture = get_tile_texture(block_tile_coords)
	
	if block_texture == null:
		push_error("Failed to load block texture! Check tileset assignment.")
	
	# Create grid cells
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell = TextureRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_SCALE
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			# Start invisible
			cell.modulate = Color(1, 1, 1, 0)
			
			grid_container.add_child(cell)
			grid_cells.append(cell)
	
	print("Grid overlay created at ", grid_screen_pos)
	print("Grid cells: ", grid_cells.size())

func get_tile_texture(coords: Vector2i) -> AtlasTexture:
	var cache_key = str(coords)
	if tile_texture_cache.has(cache_key):
		return tile_texture_cache[cache_key]
	
	if tileset == null:
		push_error("Tileset not assigned!")
		return null
	
	var source = tileset.get_source(source_id)
	if source is TileSetAtlasSource:
		var atlas_source = source as TileSetAtlasSource
		var tile_texture = AtlasTexture.new()
		tile_texture.atlas = atlas_source.texture
		tile_texture.region = atlas_source.get_tile_texture_region(coords)
		tile_texture_cache[cache_key] = tile_texture
		return tile_texture
	
	return null

func update_grid_visual():
	var blocked = GridManager.get_blocked_cells()
	var block_texture = get_tile_texture(block_tile_coords)
	
	print("\n=== UPDATING GRID VISUAL ===")
	print("Blocked cells: ", blocked)
	
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var index = y * GRID_SIZE.x + x
			var cell = grid_cells[index] as TextureRect
			var grid_pos = Vector2i(x, y)
			
			if grid_pos in blocked:
				cell.texture = block_texture
				cell.modulate = Color(1, 1, 1, 1)
				print("  Cell ", grid_pos, " → BLOCKED")
			else:
				cell.modulate = Color(1, 1, 1, 0)
	
	print("=== GRID UPDATED ===\n")

func start_wave():
	current_wave += 1
	wave_active = true
	enemies_alive = 0
	
	print("\n=== WAVE ", current_wave, " START ===")
	
	# Update grid visual
	update_grid_visual()
	
	spawn_wave_enemies()

func spawn_wave_enemies():
	var enemy_count = 3 + (current_wave - 1) * 2
	
	print("Spawning ", enemy_count, " enemies...")
	
	for i in enemy_count:
		await get_tree().create_timer(0.3).timeout
		spawn_single_enemy()

func spawn_single_enemy():
	var enemy = enemy_spawner.spawn_enemy()
	if enemy and enemy.has_signal("enemy_died"):
		enemies_alive += 1
		enemy.enemy_died.connect(_on_enemy_died)

func _on_enemy_died():
	enemies_alive -= 1
	print("Enemy died! Remaining: ", enemies_alive)
	
	if enemies_alive <= 0 and wave_active:
		wave_complete()

func wave_complete():
	wave_active = false
	print("=== WAVE COMPLETE ===")
	await get_tree().create_timer(1.0).timeout
	show_upgrade_screen()

func show_upgrade_screen():
	get_tree().paused = true
	upgrade_screen.show()

func _on_upgrades_confirmed():
	print("Upgrades confirmed!")
	upgrade_screen.hide()
	
	# Update main scene grid
	update_grid_visual()
	
	get_tree().paused = false
	start_wave()

func _on_skip_upgrades():
	print("Skipped upgrades")
	upgrade_screen.hide()
	get_tree().paused = false
	start_wave()

func _input(event):
	# Print mouse position on click
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_viewport().get_mouse_position()
			print("\n=== CLICKED at: (%.0f, %.0f) ===" % [mouse_pos.x, mouse_pos.y])
	
	# Test show blocks
	if event.is_action_pressed("ui_text_backspace"):
		test_show_blocks()

func test_show_blocks():
	print("\n=== TEST: Showing first 10 cells ===")
	
	var block_texture = get_tile_texture(block_tile_coords)
	
	if block_texture == null:
		push_error("Block texture is null! Can't show test blocks.")
		return
	
	# Show first 10 cells
	for i in range(min(10, grid_cells.size())):
		var cell = grid_cells[i] as TextureRect
		cell.texture = block_texture
		cell.modulate = Color(1, 1, 1, 1)
		print("  Cell ", i, " visible")
	
	print("First 10 cells should be visible now!")
	print("(Top row of grid)")
