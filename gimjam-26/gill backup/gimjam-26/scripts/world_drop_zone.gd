extends Control

@export var world_item_scene: PackedScene
# FIX 1: Assign this in the Inspector so we can find the neighbor node safely
@export var equip_slots: Control 

func _can_drop_data(_at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("item") and data["item"] is WeaponData

func _drop_data(_at_position, data):
	var weapon = data["item"]
	var source_slot = data["source"]
	
	# 1. Spawn the item first
	spawn_item_in_world(weapon)
	
	# 2. Clear the source slot (This runs now because we fixed the crash above)
	source_slot.set_item(null)
	
	# 3. Update the Inventory UI
	# FIX 2: Use the export variable instead of find_child
	if equip_slots and equip_slots.has_method("update_equipped_weapons"):
		equip_slots.update_equipped_weapons()
	else:
		print("Error: EquipSlots not assigned in Inspector!")

func spawn_item_in_world(weapon_data):
	var drop = world_item_scene.instantiate()
	
	# Coordinate Conversion
	var world_mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
	drop.global_position = world_mouse_pos
	
	get_tree().current_scene.add_child(drop)
	
	# FIX 3: Robust Node Finding
	# We try to find the button by type or common names to prevent crashes
	var button_node = null
	
	if drop.has_node("TextureButton"):
		button_node = drop.get_node("TextureButton")
	elif drop.has_node("PlayerInventory"): # In case you actually named it this
		button_node = drop.get_node("PlayerInventory")
	else:
		# Fallback: Just grab the first child if specific names fail
		if drop.get_child_count() > 0:
			button_node = drop.get_child(0)

	# Apply the data safely
	if button_node and button_node.has_method("set_item"):
		button_node.set_item(weapon_data)
	else:
		print("Error: Could not find a node with 'set_item' inside the dropped scene.")
