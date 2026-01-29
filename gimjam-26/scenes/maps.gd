# res://scenes/maps.gd
# Attach to: MainScene/Background
# Supports Map1..MapN using arrays
# Transition behavior:
# - On EXIT: show Trans node for 1.5s, then load next map
# - Player hidden + input locked during transition
# - After map loads: player still hidden + input locked until ESC (ui_cancel)

extends Node2D

# Drag your Map1.tscn, Map2.tscn, Map3.tscn ... here in Inspector (order matters)
@export var map_scenes: Array[PackedScene] = []

# Start index (0 = Map1, 1 = Map2, 2 = Map3, ...)
@export var start_map_index: int = 0

# Player is a sibling of Background in your main_scene.tscn
@export var player_path: NodePath = NodePath("../Player")

@export var spawn_inside_tiles: int = 1

# Exit trigger tuning
@export var exit_trigger_delay_frames: int = 3

# --- NEW: Transition screen node (your Node2D named "Trans") ---
@export var transition_node_path: NodePath = NodePath("Trans")
@export var transition_duration: float = 1.5

# Keep previous ESC transition behavior
@export var transition_requires_esc: bool = true


var current_map: Node2D = null
var _current_map_index: int = 0

# Preserve editor placement for each map name -> transform
var _map_xforms: Dictionary = {} # key: "Map1"/"Map2"/...  value: Transform2D

# Runtime exit trigger
var _exit_trigger: Area2D = null
var _is_switching_map := false

# Transition state (ESC gate)
var _transition_waiting_for_esc := false

# Transition screen reference
var _trans: Node2D = null


func _ready() -> void:
	print("BG DEBUG: Background script running on node =", name, " path=", get_path())

	# Grab transition screen node
	_trans = get_node_or_null(transition_node_path) as Node2D
	if _trans != null:
		_trans.visible = false
		# ensure it's above maps when shown
		_trans.z_index = 9999

	_autoload_scenes_and_xforms_from_children()

	if map_scenes.is_empty():
		push_error("Background: map_scenes is empty. Drag Map1..MapN scenes into Background -> map_scenes.")
		return

	start_map_index = clamp(start_map_index, 0, map_scenes.size() - 1)
	await load_map(start_map_index)

	# Ensure we start in normal state
	_finish_transition_if_needed(true)


# ---------------------------------------------------------
# Auto-capture transforms from editor-placed children named Map1/Map2/Map3...
# Then queue_free them so only runtime instance exists (avoids double physics)
# ---------------------------------------------------------
func _autoload_scenes_and_xforms_from_children() -> void:
	for c in get_children():
		if c is Node2D and (c.name.begins_with("Map")):
			var n := c as Node2D
			_map_xforms[n.name] = n.transform

			if n.scene_file_path != "":
				var ps := load(n.scene_file_path) as PackedScene
				if ps != null and not map_scenes.has(ps):
					map_scenes.append(ps)

			n.queue_free()


# ---------------------------------------------------------
# ESC-only input gate (keeps previous behavior)
# ---------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not _transition_waiting_for_esc:
		return

	# Only ESC / ui_cancel allowed
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_finish_transition()
		get_viewport().set_input_as_handled()
	else:
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------
# Map loading / unloading
# ---------------------------------------------------------
func load_map(which: int) -> void:
	print("BG DEBUG: load_map START which=", which)
	_current_map_index = which

	if which < 0 or which >= map_scenes.size():
		push_error("Background: load_map index out of range: %s" % which)
		return

	var scene := map_scenes[which]
	if scene == null:
		push_error("Background: Map scene at index %s is null." % which)
		return

	_remove_exit_trigger()

	# Remove old map completely
	if is_instance_valid(current_map):
		print("BG DEBUG: freeing old map:", current_map.name)
		current_map.queue_free()
		current_map = null

	await get_tree().process_frame

	# Instance new map
	var inst := scene.instantiate()
	if not (inst is Node2D):
		push_error("Background: Instanced map root must be Node2D.")
		add_child(inst)
		return

	current_map = inst as Node2D
	current_map.name = "Map%s" % (which + 1)
	add_child(current_map)

	# Preserve editor offset (if captured)
	if _map_xforms.has(current_map.name):
		current_map.transform = _map_xforms[current_map.name]

	print("BG DEBUG: added map node =", current_map.name, " path=", current_map.get_path())

	if not current_map.is_node_ready():
		await current_map.ready
	await get_tree().process_frame

	# Find TileMapLayer
	var layer := _find_first_tilemaplayer(current_map)
	if layer != null:
		await _wait_for_layer_gates(layer)

	# Spawn player at entrance (DO NOT force visible; transition controls visibility)
	await _spawn_player_at_entrance(current_map)

	# Create exit trigger
	if layer != null:
		_create_exit_trigger(layer)


func _wait_for_layer_gates(layer: TileMapLayer, max_frames: int = 240) -> void:
	var sentinel := Vector2i(-999999, -999999)
	for _i in range(max_frames):
		if ("entrance_gate_cell" in layer) and ("exit_gate_cell" in layer):
			if layer.entrance_gate_cell != sentinel and layer.exit_gate_cell != sentinel:
				return
		await get_tree().process_frame
	push_warning("Background: Timed out waiting for gates on %s" % layer.name)


func _spawn_player_at_entrance(map_node: Node2D) -> void:
	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		push_warning("Background: Player not found at path: %s" % str(player_path))
		return

	if not player.is_node_ready():
		await player.ready
	await get_tree().process_frame

	var layer := _find_first_tilemaplayer(map_node)
	if layer == null:
		push_warning("Background: No TileMapLayer found in %s" % map_node.name)
		return

	var entrance: Vector2i = layer.entrance_gate_cell
	var sentinel := Vector2i(-999999, -999999)
	if entrance == sentinel:
		push_warning("Background: entrance_gate_cell still sentinel on %s" % layer.name)
		return

	var rect: Rect2i = layer.get_used_rect()
	var side := _side_for_gate_cell(rect, entrance)
	var inside_step := _inside_step_for_side(side)
	var spawn_cell := entrance + inside_step * spawn_inside_tiles

	var tile_size := Vector2(layer.tile_set.tile_size)
	var local_pos: Vector2 = layer.map_to_local(spawn_cell) + tile_size * 0.5
	var global_pos: Vector2 = layer.to_global(local_pos)

	player.global_position = global_pos
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO

	await get_tree().physics_frame
	player.global_position = global_pos
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO


# ---------------------------------------------------------
# EXIT trigger creation + switching maps (sequential)
# + NEW: show Trans screen for 1.5s BEFORE showing next map
# ---------------------------------------------------------
func _remove_exit_trigger() -> void:
	if is_instance_valid(_exit_trigger):
		_exit_trigger.queue_free()
	_exit_trigger = null


func _create_exit_trigger(layer: TileMapLayer) -> void:
	_remove_exit_trigger()

	var exit_cell: Vector2i = layer.exit_gate_cell
	var sentinel := Vector2i(-999999, -999999)
	if exit_cell == sentinel:
		push_warning("Background: exit_gate_cell still sentinel; cannot create trigger")
		return

	_exit_trigger = Area2D.new()
	_exit_trigger.name = "ExitTrigger"
	_exit_trigger.monitoring = false
	_exit_trigger.monitorable = true

	layer.add_child(_exit_trigger)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(layer.tile_set.tile_size)

	var cs := CollisionShape2D.new()
	cs.shape = shape
	_exit_trigger.add_child(cs)

	var tile_size := Vector2(layer.tile_set.tile_size)
	var local_center := layer.map_to_local(exit_cell) + tile_size * 0.5
	_exit_trigger.position = local_center

	_exit_trigger.body_entered.connect(_on_exit_trigger_body_entered)

	await get_tree().physics_frame
	for _i in range(exit_trigger_delay_frames):
		await get_tree().physics_frame
	if is_instance_valid(_exit_trigger):
		_exit_trigger.monitoring = true


func _on_exit_trigger_body_entered(body: Node) -> void:
	if _is_switching_map:
		return

	var player := get_node_or_null(player_path)
	if body != player:
		return

	var next_index := _current_map_index + 1
	if next_index >= map_scenes.size():
		print("BG DEBUG: Exit reached on last map (index=", _current_map_index, "). No next map; ignoring.")
		return

	_is_switching_map = true
	print("BG DEBUG: Player entered EXIT. Switching to map index=", next_index)

	# Keep previous behavior: hide player + lock inputs until ESC
	if transition_requires_esc:
		_begin_transition()

	# NEW: show Trans screen for 1.5s BEFORE next map is shown
	await _play_between_maps_transition(next_index)

	_is_switching_map = false


func _play_between_maps_transition(next_index: int) -> void:
	# 1) Hide current map (so old map isn't visible behind Trans)
	if is_instance_valid(current_map):
		current_map.visible = false

	# 2) Show Trans on top
	_show_trans(true)

	# 3) Wait fixed time
	await get_tree().create_timer(transition_duration).timeout

	# 4) Load next map while Trans is still visible (so player never sees pop-in)
	await load_map(next_index)

	# 5) Keep Trans above the newly added map for 1 frame, then hide it
	await get_tree().process_frame
	_show_trans(false)


func _show_trans(show: bool) -> void:
	if _trans == null:
		return

	_trans.visible = show

	# Ensure it's drawn ABOVE the map that gets instanced (since load_map add_child makes map last)
	if show:
		move_child(_trans, get_child_count() - 1)
		_trans.z_index = 9999


# ---------------------------------------------------------
# Transition lock (player hidden + no input until ESC)
# This is the "previous transition" you said must stay.
# ---------------------------------------------------------
func _begin_transition() -> void:
	_transition_waiting_for_esc = true

	# Mouse should appear during the transition
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var player := get_node_or_null(player_path) as Node2D
	if player != null:
		player.visible = false

	_set_player_controls_enabled(false)


func _finish_transition() -> void:
	_transition_waiting_for_esc = false

	# Keep mouse visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_set_player_controls_enabled(true)

	var player := get_node_or_null(player_path) as Node2D
	if player != null:
		player.visible = true
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO


func _finish_transition_if_needed(force: bool = false) -> void:
	if force and _transition_waiting_for_esc:
		_finish_transition()
	elif force and not _transition_waiting_for_esc:
		_set_player_controls_enabled(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var player := get_node_or_null(player_path) as Node2D
		if player != null:
			player.visible = true


func _set_player_controls_enabled(enabled: bool) -> void:
	var player := get_node_or_null(player_path) as Node
	if player == null:
		return

	_set_node_processing_recursive(player, enabled)

	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO


func _set_node_processing_recursive(n: Node, enabled: bool) -> void:
	n.set_process(enabled)
	n.set_physics_process(enabled)
	n.set_process_input(enabled)
	n.set_process_unhandled_input(enabled)
	n.set_process_unhandled_key_input(enabled)

	for c in n.get_children():
		_set_node_processing_recursive(c, enabled)


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
func _side_for_gate_cell(rect: Rect2i, cell: Vector2i) -> String:
	var left := rect.position.x
	var right := rect.position.x + rect.size.x - 1
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y - 1

	if cell.y == top:
		return "top"
	if cell.y == bottom:
		return "bottom"
	if cell.x == left:
		return "left"
	if cell.x == right:
		return "right"

	var d_top = abs(cell.y - top)
	var d_bottom = abs(cell.y - bottom)
	var d_left = abs(cell.x - left)
	var d_right = abs(cell.x - right)

	var best = d_top
	var best_side := "top"
	if d_bottom < best:
		best = d_bottom
		best_side = "bottom"
	if d_left < best:
		best = d_left
		best_side = "left"
	if d_right < best:
		best = d_right
		best_side = "right"
	return best_side


func _inside_step_for_side(side: String) -> Vector2i:
	match side:
		"top": return Vector2i(0, 1)
		"bottom": return Vector2i(0, -1)
		"left": return Vector2i(1, 0)
		"right": return Vector2i(-1, 0)
		_: return Vector2i(0, 1)


func _find_first_tilemaplayer(root: Node) -> TileMapLayer:
	if root.has_node("TileMapLayer"):
		return root.get_node("TileMapLayer") as TileMapLayer

	for c in root.get_children():
		if c is TileMapLayer:
			return c
		if c.get_child_count() > 0:
			var found := _find_first_tilemaplayer(c)
			if found != null:
				return found
	return null
