# res://scenes/maps.gd
# Attach to: MainScene/Background

extends Node2D

@export var map_scenes: Array[PackedScene] = []
@export var start_map_index: int = 0
@export var player_path: NodePath = NodePath("../Player")
@export var spawn_inside_tiles: int = 1
@export var exit_trigger_delay_frames: int = 3

@export var transition_node_path: NodePath = NodePath("Trans")
@export var transition_duration: float = 1.5
@export var transition_requires_esc: bool = true

var current_map: Node2D = null
var _current_map_index: int = 0
var _map_xforms: Dictionary = {}

var _exit_trigger: Area2D = null
var _is_switching_map := false

var _transition_waiting_for_esc := false
var _trans: Node2D = null

# NEW: room clear / spawner management
var _room_cleared: bool = false
var _spawners: Array = []


func _ready() -> void:
	_trans = get_node_or_null(transition_node_path) as Node2D
	if _trans != null:
		_trans.visible = false
		_trans.z_index = 9999

	_autoload_scenes_and_xforms_from_children()

	if map_scenes.is_empty():
		push_error("Background: map_scenes is empty. Drag Map1..MapN scenes into Background -> map_scenes.")
		return

	start_map_index = clamp(start_map_index, 0, map_scenes.size() - 1)
	await load_map(start_map_index)

	# Start state: normal gameplay (not in ESC lock)
	_finish_transition_if_needed(true)


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
	_current_map_index = which

	if which < 0 or which >= map_scenes.size():
		push_error("Background: load_map index out of range: %s" % which)
		return

	var scene := map_scenes[which]
	if scene == null:
		push_error("Background: Map scene at index %s is null." % which)
		return

	_remove_exit_trigger()
	_stop_all_spawners() # <- IMPORTANT

	# Remove old map completely
	if is_instance_valid(current_map):
		current_map.queue_free()
		current_map = null

	await get_tree().process_frame

	var inst := scene.instantiate()
	if not (inst is Node2D):
		push_error("Background: Instanced map root must be Node2D.")
		add_child(inst)
		return

	current_map = inst as Node2D
	current_map.name = "Map%s" % (which + 1)
	add_child(current_map)

	if _map_xforms.has(current_map.name):
		current_map.transform = _map_xforms[current_map.name]

	if not current_map.is_node_ready():
		await current_map.ready
	await get_tree().process_frame

	# Find TileMapLayer + wait for gates
	var layer := _find_first_tilemaplayer(current_map)
	if layer != null:
		await _wait_for_layer_gates(layer)

	# Spawn player at entrance (don’t force visible here)
	await _spawn_player_at_entrance(current_map)

	# Reset room state for this map
	_room_cleared = false
	_cache_spawners_for_current_map()
	_wire_spawner_signals()

	# If there are no spawners, consider room cleared immediately
	if _spawners.is_empty():
		_room_cleared = true

	# Create exit trigger (still disabled until room cleared + transition unlocked)
	if layer != null:
		_create_exit_trigger(layer)

	# Start spawning ONLY if we are not currently waiting for ESC
	# (this prevents spawn-before-ESC completely)
	if not _transition_waiting_for_esc:
		_start_all_spawners()

	_update_exit_enabled()


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
		return

	if not player.is_node_ready():
		await player.ready
	await get_tree().process_frame

	var layer := _find_first_tilemaplayer(map_node)
	if layer == null:
		return

	var entrance: Vector2i = layer.entrance_gate_cell
	var sentinel := Vector2i(-999999, -999999)
	if entrance == sentinel:
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
# Exit trigger + switching maps
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

	# wait initial delay (but still won’t enable unless room cleared + not ESC-locked)
	await get_tree().physics_frame
	for _i in range(exit_trigger_delay_frames):
		await get_tree().physics_frame

	_update_exit_enabled()


func _update_exit_enabled() -> void:
	if not is_instance_valid(_exit_trigger):
		return

	# Exit is only enabled when:
	# - room is cleared (all enemies dead)
	# - not waiting for ESC
	_exit_trigger.monitoring = (_room_cleared and not _transition_waiting_for_esc)


func _on_exit_trigger_body_entered(body: Node) -> void:
	if _is_switching_map:
		return

	var player := get_node_or_null(player_path)
	if body != player:
		return

	# hard gate: if room not cleared, ignore
	if not _room_cleared:
		return

	var next_index := _current_map_index + 1
	if next_index >= map_scenes.size():
		print("BG DEBUG: Exit reached on last map. Ignoring.")
		return

	_is_switching_map = true

	if transition_requires_esc:
		_begin_transition()

	await _play_between_maps_transition(next_index)

	_is_switching_map = false


func _play_between_maps_transition(next_index: int) -> void:
	# stop spawners immediately
	_stop_all_spawners()

	if is_instance_valid(current_map):
		current_map.visible = false

	_show_trans(true)
	await get_tree().create_timer(transition_duration).timeout

	await load_map(next_index)

	await get_tree().process_frame
	_show_trans(false)


func _show_trans(show: bool) -> void:
	if _trans == null:
		return
	_trans.visible = show
	if show:
		move_child(_trans, get_child_count() - 1)
		_trans.z_index = 9999


# ---------------------------------------------------------
# ESC Transition lock (keep existing behavior)
# + NEW: also prevents spawning until ESC
# ---------------------------------------------------------
func _begin_transition() -> void:
	_transition_waiting_for_esc = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var player := get_node_or_null(player_path) as Node2D
	if player != null:
		player.visible = false

	_set_player_controls_enabled(false)

	# NEW: lock exit + stop spawning while waiting for ESC
	_stop_all_spawners()
	_update_exit_enabled()


func _finish_transition() -> void:
	_transition_waiting_for_esc = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_set_player_controls_enabled(true)

	var player := get_node_or_null(player_path) as Node2D
	if player != null:
		player.visible = true
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO

	# NEW: start spawners only now (prevents spawn-before-ESC)
	_start_all_spawners()
	_update_exit_enabled()


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
# Spawner + room clear handling
# ---------------------------------------------------------
func _cache_spawners_for_current_map() -> void:
	_spawners.clear()
	if not is_instance_valid(current_map):
		return

	# Find any spawner scripts (group-based)
	for node in current_map.get_children():
		_collect_spawners_recursive(node)


func _collect_spawners_recursive(n: Node) -> void:
	if n.is_in_group("enemy_spawner"):
		_spawners.append(n)
	for c in n.get_children():
		_collect_spawners_recursive(c)


func _wire_spawner_signals() -> void:
	# mark room cleared when ANY spawner emits cleared,
	# but only once ALL spawners are cleared
	for sp in _spawners:
		if sp.has_signal("room_cleared"):
			# avoid double connections
			if not sp.room_cleared.is_connected(_on_any_spawner_room_cleared):
				sp.room_cleared.connect(_on_any_spawner_room_cleared)


func _on_any_spawner_room_cleared() -> void:
	# room cleared only when ALL spawners cleared
	for sp in _spawners:
		if sp.has_method("is_cleared"):
			if not sp.is_cleared():
				return
	# all cleared
	_room_cleared = true
	_update_exit_enabled()


func _start_all_spawners() -> void:
	# only start if not already cleared
	if _room_cleared:
		return

	for sp in _spawners:
		if sp.has_method("start_spawning"):
			sp.start_spawning()


func _stop_all_spawners() -> void:
	for sp in _spawners:
		if sp.has_method("stop_spawning"):
			sp.stop_spawning()


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------
func _side_for_gate_cell(rect: Rect2i, cell: Vector2i) -> String:
	var left := rect.position.x
	var right := rect.position.x + rect.size.x - 1
	var top := rect.position.y
	var bottom := rect.position.y + rect.size.y - 1

	if cell.y == top: return "top"
	if cell.y == bottom: return "bottom"
	if cell.x == left: return "left"
	if cell.x == right: return "right"

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
