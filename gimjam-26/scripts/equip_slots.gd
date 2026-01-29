extends Control

@export var slot_1: EquipSlot
@export var slot_2: EquipSlot

@export var item_scene: PackedScene
# Reference to the player's AimController
# You might need to find this differently depending on your scene tree
@onready var player_aim = get_tree().get_first_node_in_group("Player").get_node("AimController")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_U:
			drop_item_from_slot(slot_1)
			
		# Press 'I' to drop Slot 2
		if event.keycode == KEY_I:
			drop_item_from_slot(slot_2)
			
func drop_item_from_slot(slot: EquipSlot):
	# 1. Safety Checks
	if slot.weapon_data == null: 
		return # Nothing to drop
	if item_scene == null:
		print("Error: World Item Scene not assigned in EquipSlots!")
		return

	# 2. Instantiate the drop
	var drop = item_scene.instantiate()
	
	# 3. Position it at the Player (not the mouse, since we are using keys)
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		# Drop slightly below the player so they don't instantly pick it back up
		drop.global_position = player.global_position + Vector2(0, 30)
	
	get_tree().current_scene.add_child(drop)
	
	# 4. Pass the Data to the dropped item
	# (We reuse the robust finding logic here just in case)
	var button_node = drop.get_node_or_null("TextureButton") 
	if button_node and button_node.has_method("set_item"):
		button_node.set_item(slot.weapon_data)
	
	# 5. Clear the Slot and Update
	slot.set_item(null)
	update_equipped_weapons()
	
func update_equipped_weapons():
	# We send the data from the slots directly to the player
	if player_aim:
		player_aim.update_loadout(slot_1.weapon_data, slot_2.weapon_data)

func try_add_item(new_weapon:WeaponData) -> bool:
	if slot_1.weapon_data == null:
		slot_1.set_item(new_weapon)
		update_equipped_weapons()
		return true
		
	# Check Slot 2
	if slot_2.weapon_data == null:
		slot_2.set_item(new_weapon)
		update_equipped_weapons()
		return true
		
	return false
