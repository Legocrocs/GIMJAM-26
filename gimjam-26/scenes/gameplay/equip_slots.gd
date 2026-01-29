extends Control

@export var slot_1: EquipSlot
@export var slot_2: EquipSlot

# Reference to the player's AimController
# You might need to find this differently depending on your scene tree
@onready var player_aim = get_tree().get_first_node_in_group("Player").get_node("AimController")

func update_equipped_weapons():
	# We send the data from the slots directly to the player
	if player_aim:
		player_aim.update_loadout(slot_1.weapon_data, slot_2.weapon_data)
