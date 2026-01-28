extends TileMapLayer

@export var avoid_corners_tiles: int = 2

# Gate tiles per side (CORRECTED atlas coords)
@export var gate_source_id: int = 0
@export var gate_top_atlas: Vector2i = Vector2i(0, 4)
@export var gate_right_atlas: Vector2i = Vector2i(1, 4)
@export var gate_bottom_atlas: Vector2i = Vector2i(1, 5)
@export var gate_left_atlas: Vector2i = Vector2i(0, 5)
@export var gate_alt_id: int = 0

# Rock config (atlas coords from (0,0) to (2,2))
@export var rock_source_id: int = 0
@export var rock_min_atlas: Vector2i = Vector2i(0, 0)
@export var rock_max_atlas: Vector2i = Vector2i(2, 2)
@export var rock_alt_id: int = 0

# Optional spacing (0 = off)
@export var min_gate_separation_tiles: int = 6

@export var debug_print: bool = false

# Public results (for parent to read later)
var entrance_gate_cell: Vector2i = Vector2i(-999999, -999999)
var exit_gate_cell: Vector2i = Vector2i(-999999, -999999)

# Optional: list of both (entrance first, exit second)
var gate_cells := PackedVector2Array()

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	spawn_two_gates()

func spawn_two_gates(rng_seed: int = -1) -> void:
	if rng_seed != -1:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	gate_cells = PackedVector2Array()
	entrance_gate_cell = Vector2i(-999999, -999999)
	exit_gate_cell = Vector2i(-999999, -999999)

	if get_used_cells().is_empty():
		return

	var rect: Rect2i = get_used_rect()
	if rect.size == Vector2i.ZERO:
		return

	# 1) Build raw perimeter cells by side
	var side_cells := {
		"top": _side_cells_top(rect),
		"right": _side_cells_right(rect),
		"bottom": _side_cells_bottom(rect),
		"left": _side_cells_left(rect),
	}

	# 2) Candidate cells per side:
	#    - detect most common wall tile on that side
	#    - keep only those wall cells
	#    - keep only those NOT blocked by rock "inside"
	var candidates_by_side := {
		"top": PackedVector2Array(),
		"right": PackedVector2Array(),
		"bottom": PackedVector2Array(),
		"left": PackedVector2Array()
	}

	for side in ["top", "right", "bottom", "left"]:
		var cells: PackedVector2Array = side_cells[side]
		var wall_key = _detect_most_common_tile_key(cells)
		if wall_key == null:
			continue

		var wall_cells := PackedVector2Array()
		for i in range(cells.size()):
			var c: Vector2i = cells[i]
			if _same_key(_tile_key(c), wall_key):
				wall_cells.append(c)

		var accessible := PackedVector2Array()
		for i in range(wall_cells.size()):
			var gate_cell: Vector2i = wall_cells[i]
			if _is_gate_accessible(gate_cell, side):
				accessible.append(gate_cell)

		candidates_by_side[side] = accessible

	# 3) Available sides = sides with >= 1 accessible candidate
	var available_sides := PackedStringArray()
	for side in ["top", "right", "bottom", "left"]:
		if (candidates_by_side[side] as PackedVector2Array).size() > 0:
			available_sides.append(side)

	if debug_print:
		print("Accessible candidate counts: ",
			"top=", (candidates_by_side["top"] as PackedVector2Array).size(), ", ",
			"right=", (candidates_by_side["right"] as PackedVector2Array).size(), ", ",
			"bottom=", (candidates_by_side["bottom"] as PackedVector2Array).size(), ", ",
			"left=", (candidates_by_side["left"] as PackedVector2Array).size()
		)

	if available_sides.size() < 2:
		if debug_print:
			print("Not enough accessible sides to place 2 gates.")
		return

	# 4) Pick 2 distinct sides (first = entrance, second = exit)
	var idx1 := _rng.randi_range(0, available_sides.size() - 1)
	var side1 := available_sides[idx1]
	available_sides.remove_at(idx1)

	var idx2 := _rng.randi_range(0, available_sides.size() - 1)
	var side2 := available_sides[idx2]

	if debug_print:
		print("Chosen sides: ", side1, " (entrance) and ", side2, " (exit)")

	# 5) Place exactly 1 gate on each chosen side
	var placed := PackedVector2Array()

	var e := _place_one_gate_on_side(side1, candidates_by_side[side1], placed)
	if e != Vector2i(999999, 999999):
		entrance_gate_cell = e

	var x := _place_one_gate_on_side(side2, candidates_by_side[side2], placed)
	if x != Vector2i(999999, 999999):
		exit_gate_cell = x

	# Save to list too (entrance first, exit second)
	if entrance_gate_cell != Vector2i(-999999, -999999):
		gate_cells.append(entrance_gate_cell)
	if exit_gate_cell != Vector2i(-999999, -999999):
		gate_cells.append(exit_gate_cell)

	# Rebuild internal caches (including collisions) after edits
	call_deferred("update_internals")

# Returns the chosen cell (or sentinel if failed)
func _place_one_gate_on_side(side: String, pool: PackedVector2Array, placed: PackedVector2Array) -> Vector2i:
	if pool.size() == 0:
		return Vector2i(999999, 999999)

	var chosen := _pick_cell_with_separation(pool, placed)
	if chosen == Vector2i(999999, 999999):
		return Vector2i(999999, 999999)

	# IMPORTANT: remove the stone first so its collision doesn't remain
	_carve_gate_cell(chosen, side)

	placed.append(chosen)
	return chosen

func _carve_gate_cell(gate_cell: Vector2i, side: String) -> void:
	erase_cell(gate_cell)
	_set_cell_from_key(gate_cell, _gate_key_for_side(side))
	call_deferred("update_internals")

# ---------------------------
# Accessibility checks
# ---------------------------

func _is_gate_accessible(gate_cell: Vector2i, side: String) -> bool:
	var inside := gate_cell + _inside_step_for_side(side)
	if get_cell_source_id(inside) == -1:
		return false
	return not _is_rock_cell(inside)

func _inside_step_for_side(side: String) -> Vector2i:
	match side:
		"top": return Vector2i(0, 1)
		"bottom": return Vector2i(0, -1)
		"left": return Vector2i(1, 0)
		"right": return Vector2i(-1, 0)
		_: return Vector2i.ZERO

func _is_rock_cell(cell: Vector2i) -> bool:
	if get_cell_source_id(cell) != rock_source_id:
		return false
	if get_cell_alternative_tile(cell) != rock_alt_id:
		return false

	var a := get_cell_atlas_coords(cell)
	return (
		a.x >= rock_min_atlas.x and a.x <= rock_max_atlas.x and
		a.y >= rock_min_atlas.y and a.y <= rock_max_atlas.y
	)

# ---------------------------
# Picking helpers
# ---------------------------

func _pick_cell_with_separation(pool: PackedVector2Array, placed: PackedVector2Array) -> Vector2i:
	if pool.size() == 0:
		return Vector2i(999999, 999999)

	if placed.size() == 0 or min_gate_separation_tiles <= 0:
		return pool[_rng.randi_range(0, pool.size() - 1)]

	var valid := PackedVector2Array()
	for i in range(pool.size()):
		var c: Vector2i = pool[i]
		var ok := true
		for j in range(placed.size()):
			var p: Vector2i = placed[j]
			if _manhattan(c, p) < min_gate_separation_tiles:
				ok = false
				break
		if ok:
			valid.append(c)

	if valid.size() > 0:
		return valid[_rng.randi_range(0, valid.size() - 1)]

	return pool[_rng.randi_range(0, pool.size() - 1)]

# ---------------------------
# Gate tile selection
# ---------------------------

func _gate_key_for_side(side: String) -> Array:
	match side:
		"top":
			return [gate_source_id, gate_top_atlas, gate_alt_id]
		"right":
			return [gate_source_id, gate_right_atlas, gate_alt_id]
		"bottom":
			return [gate_source_id, gate_bottom_atlas, gate_alt_id]
		"left":
			return [gate_source_id, gate_left_atlas, gate_alt_id]
		_:
			return [gate_source_id, gate_top_atlas, gate_alt_id]

# ---------------------------
# Tile helpers
# ---------------------------

func _tile_key(cell: Vector2i) -> Variant:
	var sid := get_cell_source_id(cell)
	if sid == -1:
		return null
	return [sid, get_cell_atlas_coords(cell), get_cell_alternative_tile(cell)]

func _set_cell_from_key(cell: Vector2i, key: Array) -> void:
	set_cell(cell, key[0], key[1], key[2])

func _same_key(a: Variant, b: Variant) -> bool:
	return a != null and b != null and a[0] == b[0] and a[1] == b[1] and a[2] == b[2]

func _detect_most_common_tile_key(cells: PackedVector2Array) -> Variant:
	var counts := {}
	for i in range(cells.size()):
		var c: Vector2i = cells[i]
		var k = _tile_key(c)
		if k == null:
			continue
		counts[k] = int(counts.get(k, 0)) + 1

	var best_key = null
	var best_count := -1
	for k in counts.keys():
		var ct: int = counts[k]
		if ct > best_count:
			best_count = ct
			best_key = k

	return best_key

# ---------------------------
# Geometry helpers (per side)
# ---------------------------

func _side_cells_top(rect: Rect2i) -> PackedVector2Array:
	var cells := PackedVector2Array()
	var left := rect.position.x
	var right := rect.position.x + rect.size.x - 1
	var top := rect.position.y
	for x in range(left + avoid_corners_tiles, right - avoid_corners_tiles + 1):
		var c := Vector2i(x, top)
		if get_cell_source_id(c) != -1:
			cells.append(c)
	return cells

func _side_cells_bottom(rect: Rect2i) -> PackedVector2Array:
	var cells := PackedVector2Array()
	var left := rect.position.x
	var right := rect.position.x + rect.size.x - 1
	var bottom := rect.position.y + rect.size.y - 1
	for x in range(left + avoid_corners_tiles, right - avoid_corners_tiles + 1):
		var c := Vector2i(x, bottom)
		if get_cell_source_id(c) != -1:
			cells.append(c)
	return cells

func _side_cells_left(rect: Rect2i) -> PackedVector2Array:
	var cells := PackedVector2Array()
	var left := rect.position.x
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y - 1
	for y in range(top + avoid_corners_tiles, bottom - avoid_corners_tiles + 1):
		var c := Vector2i(left, y)
		if get_cell_source_id(c) != -1:
			cells.append(c)
	return cells

func _side_cells_right(rect: Rect2i) -> PackedVector2Array:
	var cells := PackedVector2Array()
	var right := rect.position.x + rect.size.x - 1
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y - 1
	for y in range(top + avoid_corners_tiles, bottom - avoid_corners_tiles + 1):
		var c := Vector2i(right, y)
		if get_cell_source_id(c) != -1:
			cells.append(c)
	return cells

func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
