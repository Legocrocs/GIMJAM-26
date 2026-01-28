# grid_manager.gd
extends Node

const GRID_SIZE = Vector2i(10, 8)  # ← Ganti jadi 10x8

# Grid state - true = blocked, false = available
var grid_state: Array = []
var placed_upgrades: Array = []

signal grid_updated

func _ready():
	initialize_grid()

func initialize_grid():
	grid_state.clear()
	placed_upgrades.clear()
	
	for y in GRID_SIZE.y:
		var row = []
		for x in GRID_SIZE.x:
			row.append(false)
		grid_state.append(row)

func is_valid_placement(shape: Array[Vector2i], grid_pos: Vector2i) -> bool:
	for offset in shape:
		var check_pos = grid_pos + offset
		
		if check_pos.x < 0 or check_pos.x >= GRID_SIZE.x:
			return false
		if check_pos.y < 0 or check_pos.y >= GRID_SIZE.y:
			return false
		
		if grid_state[check_pos.y][check_pos.x]:
			return false
	
	return true

func place_upgrade(upgrade: UpgradeItem, grid_pos: Vector2i) -> bool:
	if not is_valid_placement(upgrade.grid_shape, grid_pos):
		return false
	
	for offset in upgrade.grid_shape:
		var cell_pos = grid_pos + offset
		grid_state[cell_pos.y][cell_pos.x] = true
	
	placed_upgrades.append({
		"upgrade": upgrade,
		"position": grid_pos
	})
	
	grid_updated.emit()
	return true

func remove_upgrade(grid_pos: Vector2i) -> bool:
	if not grid_state[grid_pos.y][grid_pos.x]:
		return false
	
	for i in range(placed_upgrades.size() - 1, -1, -1):
		var data = placed_upgrades[i]
		var upgrade_pos = data.position
		var shape = data.upgrade.grid_shape
		
		for offset in shape:
			if upgrade_pos + offset == grid_pos:
				for clear_offset in shape:
					var clear_pos = upgrade_pos + clear_offset
					grid_state[clear_pos.y][clear_pos.x] = false
				
				placed_upgrades.remove_at(i)
				grid_updated.emit()
				return true
	
	return false

func get_blocked_cells() -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for y in GRID_SIZE.y:
		for x in GRID_SIZE.x:
			if grid_state[y][x]:
				blocked.append(Vector2i(x, y))
	return blocked

func clear_all():
	initialize_grid()
	grid_updated.emit()
