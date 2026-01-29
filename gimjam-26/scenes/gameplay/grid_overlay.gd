# grid_overlay.gd - CLEAN VERSION (no calibration controls)
extends CanvasLayer

const GRID_SIZE = Vector2i(14, 12)
var grid_start_pos = Vector2(58.54546, 48.33329)
var cell_size = 46.3866939621603

var dragging_upgrade: UpgradeItem = null
var hover_grid_pos = Vector2i(-1, -1)
var is_upgrade_phase = false

var draw_node: Node2D 

signal upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i)

func _ready():
	draw_node = Node2D.new()
	draw_node.name = "DrawNode"
	add_child(draw_node)
	draw_node.draw.connect(_on_draw)
	
	visible = false
	set_process(false)

func show_grid():
	visible = true
	is_upgrade_phase = true
	set_process(true)
	draw_node.queue_redraw()

func hide_grid():
	visible = false
	is_upgrade_phase = false
	dragging_upgrade = null
	set_process(false)

func start_drag(upgrade: UpgradeItem):
	if not is_upgrade_phase: return
	dragging_upgrade = upgrade
	hover_grid_pos = Vector2i(-1, -1)
	print("Started dragging: ", upgrade.upgrade_name)
	draw_node.queue_redraw()

func _on_draw():
	if not is_upgrade_phase: return
	
	var grid_width = GRID_SIZE.x * cell_size
	var grid_height = GRID_SIZE.y * cell_size
	
	# Draw background
	draw_node.draw_rect(
		Rect2(grid_start_pos, Vector2(grid_width, grid_height)), 
		Color(0, 0, 0, 0.7), 
		true
	)
	
	# Draw grid lines
	for x in GRID_SIZE.x + 1:
		var x_pos = grid_start_pos.x + x * cell_size
		draw_node.draw_line(
			Vector2(x_pos, grid_start_pos.y),
			Vector2(x_pos, grid_start_pos.y + grid_height),
			Color.WHITE, 2.0
		)
	
	for y in GRID_SIZE.y + 1:
		var y_pos = grid_start_pos.y + y * cell_size
		draw_node.draw_line(
			Vector2(grid_start_pos.x, y_pos),
			Vector2(grid_start_pos.x + grid_width, y_pos),
			Color.WHITE, 2.0
		)
	
	# Draw placed blocks
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			if GridManager.grid_state[y][x]:
				var pos = grid_start_pos + Vector2(x * cell_size, y * cell_size)
				draw_node.draw_rect(
					Rect2(pos, Vector2(cell_size, cell_size)), 
					Color(1, 0.5, 0, 0.5), 
					true
				)
	
	# Draw preview - recalculate position each frame
	if dragging_upgrade:
		var mouse_pos = get_viewport().get_mouse_position()
		var current_hover = screen_to_grid(mouse_pos)
		
		if current_hover != Vector2i(-1, -1):
			draw_upgrade_preview(current_hover)

func draw_upgrade_preview(grid_pos: Vector2i):
	var is_valid = GridManager.is_valid_placement(dragging_upgrade.grid_shape, grid_pos)
	var color = Color(0, 1, 0, 0.7) if is_valid else Color(1, 0, 0, 0.7)
	
	for offset in dragging_upgrade.grid_shape:
		var cell = grid_pos + offset
		
		if cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y:
			var pos = grid_start_pos + Vector2(cell.x * cell_size, cell.y * cell_size)
			draw_node.draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color, true)
			draw_node.draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color.WHITE, false, 4.0)

func _process(_delta):
	if is_upgrade_phase:
		draw_node.queue_redraw()  # Redraw every frame for smooth preview

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var local_pos = screen_pos - grid_start_pos
	
	if local_pos.x < 0 or local_pos.y < 0:
		return Vector2i(-1, -1)
	
	var grid_x = int(floor(local_pos.x / cell_size))
	var grid_y = int(floor(local_pos.y / cell_size))
	
	if grid_x >= GRID_SIZE.x or grid_y >= GRID_SIZE.y:
		return Vector2i(-1, -1)
	
	return Vector2i(grid_x, grid_y)

func _input(event):
	if not is_upgrade_phase:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_upgrade:
			var mouse_pos = get_viewport().get_mouse_position()
			hover_grid_pos = screen_to_grid(mouse_pos)
			
			if hover_grid_pos != Vector2i(-1, -1):
				try_place_upgrade()
			
			stop_dragging()

func try_place_upgrade():
	if GridManager.place_upgrade(dragging_upgrade, hover_grid_pos):
		print("Successfully placed upgrade at: ", hover_grid_pos)
		upgrade_placed.emit(dragging_upgrade, hover_grid_pos)
	else:
		print("Invalid placement at: ", hover_grid_pos)

func stop_dragging():
	dragging_upgrade = null
	hover_grid_pos = Vector2i(-1, -1)
	draw_node.queue_redraw()
