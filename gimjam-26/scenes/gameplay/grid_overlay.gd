extends Control

# Signals
signal upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i)

# --- SETTINGS (Calibrated from your previous file) ---
# Exported for easier adjustment in the Inspector
@export var grid_dimensions := Vector2i(14, 12)
@export var cell_size := 46.4
@export var grid_start_pos := Vector2(58.5, 48.3)

# --- STATE ---
var ghost_block: UpgradeItem = null
var ghost_grid_pos := Vector2i(-1, -1)

func _ready():
	# CRITICAL: Ensures this node can "catch" mouse events
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect to GridManager updates if needed (optional)
	if GridManager.has_signal("grid_updated"):
		GridManager.grid_updated.connect(queue_redraw)

# --- VISIBILITY CONTROL ---
func show_grid():
	visible = true
	queue_redraw()

func hide_grid():
	visible = false
	ghost_block = null
	queue_redraw()

# --- DRAWING LOGIC ---
func _draw():
	# 1. Draw the Grid Lines
	draw_grid_lines()
	
	# 2. Draw Occupied Cells (orange blocks)
	# [cite_start]This reads directly from your global GridManager [cite: 11]
	draw_occupied_cells()
	
	# 3. Draw the "Ghost" Block (Green/Red preview)
	# This only appears when you are dragging a block over the grid
	if ghost_block and ghost_grid_pos != Vector2i(-1, -1):
		draw_preview_block(ghost_block, ghost_grid_pos)

func draw_grid_lines():
	var width = grid_dimensions.x * cell_size
	var height = grid_dimensions.y * cell_size
	
	# Dark Background
	draw_rect(Rect2(grid_start_pos, Vector2(width, height)), Color(0, 0, 0, 0.6), true)
	
	# Vertical Lines
	for x in range(grid_dimensions.x + 1):
		var x_pos = grid_start_pos.x + (x * cell_size)
		draw_line(Vector2(x_pos, grid_start_pos.y), Vector2(x_pos, grid_start_pos.y + height), Color.WHITE, 1.0)
		
	# Horizontal Lines
	for y in range(grid_dimensions.y + 1):
		var y_pos = grid_start_pos.y + (y * cell_size)
		draw_line(Vector2(grid_start_pos.x, y_pos), Vector2(grid_start_pos.x + width, y_pos), Color.WHITE, 1.0)

func draw_occupied_cells():
	# Assumes GridManager is an Autoload/Singleton
	var state = GridManager.grid_state
	
	for y in range(grid_dimensions.y):
		for x in range(grid_dimensions.x):
			if state[y][x]: # If cell is true (blocked)
				var pos = grid_start_pos + Vector2(x * cell_size, y * cell_size)
				draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color(1, 0.5, 0, 0.5), true)

func draw_preview_block(block: UpgradeItem, grid_pos: Vector2i):
	# [cite_start]Check validity using the Manager [cite: 11]
	var is_valid = GridManager.is_valid_placement(block.grid_shape, grid_pos)
	var color = Color(0, 1, 0, 0.5) if is_valid else Color(1, 0, 0, 0.5)
	
	for offset in block.grid_shape:
		var cell = grid_pos + offset
		if is_cell_in_bounds(cell):
			var pos = grid_start_pos + Vector2(cell.x * cell_size, cell.y * cell_size)
			draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color, true)
			# Draw outline for better visibility
			draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color.WHITE, false, 2.0)

# --- DRAG AND DROP HANDLERS ---
func _can_drop_data(at_position, data):
	# Only accept the drop if it contains "block" data
	if typeof(data) == TYPE_DICTIONARY and data.has("block"):
		# Update the ghost block for visualization
		ghost_block = data["block"]
		ghost_grid_pos = screen_to_grid(at_position)
		
		# Force a redraw so the ghost follows the mouse
		queue_redraw()
		return true
	return false

func _drop_data(at_position, data):
	var block = data["block"]
	var source_slot = data["source"]
	var grid_pos = screen_to_grid(at_position)
	
	# Clear the ghost immediately
	ghost_block = null
	queue_redraw()
	
	if grid_pos == Vector2i(-1, -1):
		return # Dropped outside grid
	
	# Try to place the block in data
	if GridManager.place_upgrade(block, grid_pos):
		print("Placement Success at ", grid_pos)
		
		# 1. Notify Main Scene to spawn the physical wall
		upgrade_placed.emit(block, grid_pos)
		
		# 2. Remove the item from the inventory slot
		if source_slot.has_method("consume_block"):
			source_slot.consume_block()
	else:
		print("Placement Failed: Invalid or Blocked")

# Helper to clean up when dragging leaves the window
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		ghost_block = null
		queue_redraw()

# --- UTILITIES ---
func screen_to_grid(local_pos: Vector2) -> Vector2i:
	# Calculate relative to the grid start
	var rel_pos = local_pos - grid_start_pos
	
	var x = floor(rel_pos.x / cell_size)
	var y = floor(rel_pos.y / cell_size)
	
	var pos = Vector2i(int(x), int(y))
	
	if is_cell_in_bounds(pos):
		return pos
	return Vector2i(-1, -1)

func is_cell_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < grid_dimensions.x and pos.y >= 0 and pos.y < grid_dimensions.y
