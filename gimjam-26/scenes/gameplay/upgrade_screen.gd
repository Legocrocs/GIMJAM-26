# upgrade_screen.gd
extends Control

signal upgrades_confirmed

const GRID_SIZE = Vector2i(10, 8)
const CELL_SIZE = 64

@export var tileset: TileSet
@export var source_id: int = 0

@onready var grid_container = $Panel/GridContainer
@onready var upgrade_list = $Panel/UpgradeList
@onready var confirm_button = $Panel/ConfirmButton
@onready var clear_button = $Panel/ClearButton

var grid_cells: Array = []
var dragging_upgrade: UpgradeItem = null
var last_hover_pos: Vector2i = Vector2i(-1, -1)
var tile_texture_cache: Dictionary = {}

func _ready():
	setup_grid()
	setup_upgrade_list()
	
	confirm_button.pressed.connect(_on_confirm_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	
	GridManager.grid_updated.connect(refresh_grid_visual)

func get_tile_texture(coords: Vector2i) -> AtlasTexture:
	var cache_key = str(coords)
	if tile_texture_cache.has(cache_key):
		return tile_texture_cache[cache_key]
	
	if tileset == null:
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

func setup_grid():
	grid_container.columns = GRID_SIZE.x
	
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var cell = TextureRect.new()
			cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cell.stretch_mode = TextureRect.STRETCH_SCALE
			
			var bg = Panel.new()
			bg.set_anchors_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(bg)
			
			grid_container.add_child(cell)
			grid_cells.append(cell)
			
			update_cell_visual(cell, false, null)

func setup_upgrade_list():
	# Single 1x1
	add_upgrade_button(create_upgrade(
		"Single", 
		[Vector2i(0,0)],
		[Vector2i(5, 4)]  # 1 tile
	))
	
	# 1x3 Vertical
	add_upgrade_button(create_upgrade(
		"1x3 V", 
		[Vector2i(0,0), Vector2i(0,1), Vector2i(0,2)],
		[Vector2i(6, 4), Vector2i(6, 5), Vector2i(6, 6)]  # Tile sama 3x
	))
	
	# 3x1 Horizontal
	add_upgrade_button(create_upgrade(
		"3x1 H", 
		[Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)],
		[Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6)]  # Tile sama 3x
	))
	
	# 2x2 Square
	add_upgrade_button(create_upgrade(
		"2x2", 
		[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)],
		[Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5), Vector2i(4, 5)]
	))

func create_upgrade(name: String, shape: Array[Vector2i], pattern: Array[Vector2i]) -> UpgradeItem:
	var upgrade = UpgradeItem.new()
	upgrade.upgrade_name = name
	upgrade.grid_shape = shape
	upgrade.tile_pattern = pattern
	upgrade.stat_type = "damage"
	upgrade.stat_value = 10
	return upgrade

func add_upgrade_button(upgrade: UpgradeItem):
	var btn = Button.new()
	btn.text = upgrade.upgrade_name
	btn.custom_minimum_size = Vector2(120, 40)
	
	btn.gui_input.connect(func(event):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				start_dragging(upgrade)
	)
	
	upgrade_list.add_child(btn)

func start_dragging(upgrade: UpgradeItem):
	dragging_upgrade = upgrade
	last_hover_pos = Vector2i(-1, -1)

func _process(_delta):
	if dragging_upgrade != null:
		update_grid_preview()

func update_grid_preview():
	var mouse_pos = get_global_mouse_position()
	var grid_rect = grid_container.get_global_rect()
	
	if not grid_rect.has_point(mouse_pos):
		if last_hover_pos != Vector2i(-1, -1):
			refresh_grid_visual()
			last_hover_pos = Vector2i(-1, -1)
		return
	
	var local_pos = mouse_pos - grid_rect.position
	var grid_x = int(local_pos.x / CELL_SIZE)
	var grid_y = int(local_pos.y / CELL_SIZE)
	var grid_pos = Vector2i(grid_x, grid_y)
	
	grid_pos.x = clamp(grid_pos.x, 0, GRID_SIZE.x - 1)
	grid_pos.y = clamp(grid_pos.y, 0, GRID_SIZE.y - 1)
	
	if grid_pos != last_hover_pos:
		last_hover_pos = grid_pos
		show_placement_preview(grid_pos)

func show_placement_preview(grid_pos: Vector2i):
	refresh_grid_visual()
	
	var is_valid = GridManager.is_valid_placement(dragging_upgrade.grid_shape, grid_pos)
	var preview_color = Color(0, 1, 0, 0.5) if is_valid else Color(1, 0, 0, 0.5)
	
	for i in range(dragging_upgrade.grid_shape.size()):
		var offset = dragging_upgrade.grid_shape[i]
		var cell_pos = grid_pos + offset
		
		if cell_pos.x >= 0 and cell_pos.x < GRID_SIZE.x and cell_pos.y >= 0 and cell_pos.y < GRID_SIZE.y:
			var index = cell_pos.y * GRID_SIZE.x + cell_pos.x
			var cell = grid_cells[index] as TextureRect
			var bg = cell.get_child(0) as Panel
			
			bg.modulate = preview_color

func _input(event):
	if dragging_upgrade == null:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			drop_upgrade()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_drag()

func drop_upgrade():
	if dragging_upgrade == null:
		return
	
	var mouse_pos = get_global_mouse_position()
	var grid_rect = grid_container.get_global_rect()
	
	if not grid_rect.has_point(mouse_pos):
		cancel_drag()
		return
	
	if GridManager.place_upgrade(dragging_upgrade, last_hover_pos):
		print("Placed: ", dragging_upgrade.upgrade_name, " at ", last_hover_pos)
	
	cleanup_drag()

func cancel_drag():
	cleanup_drag()

func cleanup_drag():
	dragging_upgrade = null
	last_hover_pos = Vector2i(-1, -1)
	refresh_grid_visual()

func update_cell_visual(cell: TextureRect, is_blocked: bool, tile_texture: AtlasTexture):
	var bg = cell.get_child(0) as Panel
	
	if is_blocked and tile_texture != null:
		cell.texture = tile_texture
		bg.modulate = Color(1, 1, 1, 0)
	else:
		cell.texture = null
		bg.modulate = Color(0.3, 0.3, 0.4, 1)

func refresh_grid_visual():
	# Reset all cells
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			var index = y * GRID_SIZE.x + x
			update_cell_visual(grid_cells[index], false, null)
	
	# Draw placed upgrades dengan tile pattern masing-masing
	for upgrade_data in GridManager.placed_upgrades:
		var upgrade = upgrade_data.upgrade as UpgradeItem
		var pos = upgrade_data.position as Vector2i
		
		# Loop through each cell in the upgrade shape
		for i in range(upgrade.grid_shape.size()):
			var offset = upgrade.grid_shape[i]
			var cell_pos = pos + offset
			
			# Get corresponding tile from pattern
			var tile_coords = upgrade.tile_pattern[i] if i < upgrade.tile_pattern.size() else upgrade.tile_pattern[0]
			var tile_texture = get_tile_texture(tile_coords)
			
			var index = cell_pos.y * GRID_SIZE.x + cell_pos.x
			update_cell_visual(grid_cells[index], true, tile_texture)

func _on_confirm_pressed():
	upgrades_confirmed.emit()
	hide()

func _on_clear_pressed():
	GridManager.clear_all()

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var grid_rect = grid_container.get_global_rect()
		
		if grid_rect.has_point(mouse_pos):
			var local_pos = mouse_pos - grid_rect.position
			var grid_x = int(local_pos.x / CELL_SIZE)
			var grid_y = int(local_pos.y / CELL_SIZE)
			
			if grid_x >= 0 and grid_x < GRID_SIZE.x and grid_y >= 0 and grid_y < GRID_SIZE.y:
				GridManager.remove_upgrade(Vector2i(grid_x, grid_y))
