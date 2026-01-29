# grid_overlay.gd - CALIBRATION VERSION
extends CanvasLayer

const GRID_SIZE = Vector2i(10, 8)
var grid_start_pos = Vector2(72.48489, 70.75755)
var cell_size = 36.0158030130618


var dragging_upgrade: UpgradeItem = null
var hover_grid_pos = Vector2i(-1, -1)
var is_upgrade_phase = false
var calibration_mode = true # Set to true to enable editing

var draw_node: Node2D 

signal upgrade_placed(upgrade: UpgradeItem, grid_pos: Vector2i)

func _ready():
	draw_node = Node2D.new()
	draw_node.name = "DrawNode"
	add_child(draw_node)
	draw_node.draw.connect(_on_draw)
	
	visible = false
	set_process(false)
	
	print("--- CALIBRATION CONTROLS ---")
	print("ARROWS: Move Grid Position")
	print("W / S : Increase/Decrease Cell Size")
	print("ENTER : Print current values to Console")
	print("----------------------------")

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
	draw_node.queue_redraw()

func _on_draw():
	if not is_upgrade_phase: return
	
	# Use the dynamic variables here
	var grid_width = GRID_SIZE.x * cell_size
	var grid_height = GRID_SIZE.y * cell_size
	
	# Draw semi-transparent background
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
			Color.WHITE, 2.0 # Thinner lines are easier to calibrate
		)
	
	for y in GRID_SIZE.y + 1:
		var y_pos = grid_start_pos.y + y * cell_size
		draw_node.draw_line(
			Vector2(grid_start_pos.x, y_pos),
			Vector2(grid_start_pos.x + grid_width, y_pos),
			Color.WHITE, 2.0
		)
	
	# Draw placed blocks (Adjusted logic to use new variables)
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			if GridManager.grid_state[y][x]:
				var pos = grid_start_pos + Vector2(Vector2i(x, y) * cell_size)
				draw_node.draw_rect(
					Rect2(pos, Vector2(cell_size, cell_size)), 
					Color(1, 0.5, 0, 0.5), 
					true
				)
	
	# Draw preview
	if dragging_upgrade and hover_grid_pos != Vector2i(-1, -1):
		draw_upgrade_preview(hover_grid_pos)

func draw_upgrade_preview(grid_pos: Vector2i):
	var is_valid = GridManager.is_valid_placement(dragging_upgrade.grid_shape, grid_pos)
	var color = Color(0, 1, 0, 0.7) if is_valid else Color(1, 0, 0, 0.7)
	
	for offset in dragging_upgrade.grid_shape:
		var cell = grid_pos + offset
		if cell.x >= 0 and cell.x < GRID_SIZE.x and cell.y >= 0 and cell.y < GRID_SIZE.y:
			# Updated to use dynamic variables
			var pos = grid_start_pos + Vector2(cell * cell_size)
			draw_node.draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color, true)
			draw_node.draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), Color.WHITE, false, 4.0)

func _process(delta):
	# --- CALIBRATION LOGIC START ---
	if calibration_mode:
		var changed = false
		var speed = 100 * delta # Movement speed
		var scale_speed = 50 * delta # Scaling speed
		
		# Move Grid (ARROWS)
		if Input.is_key_pressed(KEY_UP): grid_start_pos.y -= speed; changed = true
		if Input.is_key_pressed(KEY_DOWN): grid_start_pos.y += speed; changed = true
		if Input.is_key_pressed(KEY_LEFT): grid_start_pos.x -= speed; changed = true
		if Input.is_key_pressed(KEY_RIGHT): grid_start_pos.x += speed; changed = true
		
		# Scale Grid (W / S)
		if Input.is_key_pressed(KEY_W): cell_size += scale_speed * delta; changed = true
		if Input.is_key_pressed(KEY_S): cell_size -= scale_speed * delta; changed = true
		
		# --- CHANGED TO "P" TO AVOID CONFLICT ---
		if Input.is_key_pressed(KEY_P):
			print("-----------------------------")
			print("FINAL VALUES FOUND:")
			print("var grid_start_pos = Vector2", grid_start_pos)
			print("var cell_size = ", cell_size)
			print("-----------------------------")
			
		if changed:
			draw_node.queue_redraw()
	# --- CALIBRATION LOGIC END ---

	if dragging_upgrade:
		var mouse_pos = get_viewport().get_mouse_position()
		var new_hover = screen_to_grid(mouse_pos)
		
		if new_hover != hover_grid_pos:
			hover_grid_pos = new_hover
			draw_node.queue_redraw()

func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	# Updated to use dynamic variables
	var local_pos = screen_pos - grid_start_pos
	
	if local_pos.x < 0 or local_pos.y < 0:
		return Vector2i(-1, -1)
	
	var grid_x = int(local_pos.x / cell_size)
	var grid_y = int(local_pos.y / cell_size)
	
	if grid_x >= GRID_SIZE.x or grid_y >= GRID_SIZE.y:
		return Vector2i(-1, -1)
	
	return Vector2i(grid_x, grid_y)

# ... _input, try_place_upgrade, stop_dragging remain the same ...
func _input(event):
	if not is_upgrade_phase:
		return
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dragging_upgrade and hover_grid_pos != Vector2i(-1, -1):
			try_place_upgrade()
		stop_dragging()

func try_place_upgrade():
	if GridManager.place_upgrade(dragging_upgrade, hover_grid_pos):
		print("Placed upgrade at: ", hover_grid_pos)
		upgrade_placed.emit(dragging_upgrade, hover_grid_pos)
	else:
		print("Invalid placement!")

func stop_dragging():
	dragging_upgrade = null
	hover_grid_pos = Vector2i(-1, -1)
	draw_node.queue_redraw()
