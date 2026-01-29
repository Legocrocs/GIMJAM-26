extends Control

const GRID_SIZE = Vector2i(14, 12)
# Keep your existing calibration values
var grid_start_pos = Vector2(58.54546, 48.33329) 
var cell_size = 46.3866939621603

# Helper to store the block we are currently dragging over the grid
var ghost_block: UpgradeItem = null 

signal upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i)

func _ready():
	# Visual setup: Make sure this overlay covers the whole screen to catch drops
	anchors_preset = Control.PRESET_FULL_RECT
	mouse_filter = Control.MOUSE_FILTER_PASS # Allow clicks to pass through if needed, but catch drops
	
	# Start hidden (Main Scene will toggle 'visible')
	visible = false

# --- DRAWING LOGIC ---

func _draw():
	var grid_width = GRID_SIZE.x * cell_size
	var grid_height = GRID_SIZE.y * cell_size
	
	# 1. Draw Background
	draw_rect(
		Rect2(grid_start_pos, Vector2(grid_width, grid_height)), 
		Color(0, 0, 0, 0.7), 
		true
	)
	
	# 2. Draw Grid Lines (Vertical)
	for x in GRID_SIZE.x + 1:
		var x_pos = grid_start_pos.x + x * cell_size
		draw_line(
			Vector2(x_pos, grid_start_pos.y),
			Vector2(x_pos, grid_start_pos.y + grid_height),
			Color.WHITE, 2.0
		)
	
	# 3. Draw Grid Lines (Horizontal)
	for y in GRID_SIZE.y + 1:
		var y_pos = grid_start_pos.y + y * cell_size
		draw_line(
			Vector2(grid_start_pos.x, y_pos),
			Vector2(grid_start_pos.x + grid_width, y_pos),
			Color.WHITE, 2.0
		)
	
	# 4. Draw Already Placed Blocks (Orange)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			if GridManager.grid_state[y][x]:
				var pos = grid_start_pos + Vector2(x * cell_size, y * cell_size)
				draw_rect(
					Rect2(pos, Vector2(cell_size, cell_size)), 
					Color(1, 0.5, 0, 0.5), 
					true
				)
	
	# 5. Draw Ghost Preview (Green/Red)
	if ghost_block:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = screen_to_grid(mouse_pos)
		
		# Only draw if we are hovering over a valid grid cell
		if grid_pos != Vector2i(-1, -1):
			draw_upgrade_preview(grid_pos)

func draw_upgrade_preview(grid_pos: Vector2i):
	# Check validity using GridManager
	var is_valid = GridManager.is_valid_placement(ghost_block.grid_shape, grid_pos)
	var color = Color(0, 1, 0, 0.7) if is_valid else Color(1, 0, 0, 0.7)
	
	for offset in ghost_block.grid_shape:
		var cell = grid_pos + offset
		
		# Ensure the shape part is inside bounds before drawing
		if cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y:
			var pos = grid_start_pos + Vector2(cell.x * cell_size, cell.y * cell_size)
			
			# Draw fill
			draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color, true)
			# Draw border
			draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color.WHITE, false, 4.0)

# --- DRAG AND DROP SYSTEM ---

# 1. Can we drop here? (Runs every frame you drag over this control)
func _can_drop_data(_at_position, data):
	# We strictly accept data that has a "block" key (UpgradeItem)
	if typeof(data) == TYPE_DICTIONARY and data.has("block") and data["block"] is UpgradeItem:
		
		# Update the ghost block for visual preview
		ghost_block = data["block"]
		queue_redraw() # Force redraw to show the green/red tiles
		return true
		
	return false

# 2. Receive the drop
func _drop_data(at_position, data):
	var block = data["block"]
	var source_slot = data["source"]
	var grid_pos = screen_to_grid(at_position)
	
	# Clear the ghost
	ghost_block = null
	queue_redraw()
	
	if grid_pos == Vector2i(-1, -1):
		return # Dropped outside the grid area
	
	# Try to place it in the data manager
	if GridManager.place_upgrade(block, grid_pos):
		print("Successfully placed block at: ", grid_pos)
		
		# Emit signal for main scene to handle effects (like spawning tilemap blocks)
		upgrade_placed.emit(block, grid_pos)
		
		# Consuming the block from inventory
		if source_slot.has_method("consume_block"):
			source_slot.consume_block()
	else:
		print("Invalid placement")

# 3. Cleanup if drag is cancelled or leaves window
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		if ghost_block:
			ghost_block = null
			queue_redraw()

# --- HELPER FUNCTIONS ---

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos = screen_pos - grid_start_pos
	
	# Check left/top bounds
	if local_pos.x < 0 or local_pos.y < 0:
		return Vector2i(-1, -1)
	
	var grid_x = int(floor(local_pos.x / cell_size))
	var grid_y = int(floor(local_pos.y / cell_size))
	
	# Check right/bottom bounds
	if grid_x >= GRID_SIZE.x or grid_y >= GRID_SIZE.y:
		return Vector2i(-1, -1)
	
	return Vector2i(grid_x, grid_y)
