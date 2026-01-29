extends Control
class_name BlockInventory

@onready var grid_container = $GridContainer # Adjust path to your container
var slots: Array[BlockSlot] = []

func _ready():
	# Auto-find all slots
	for child in grid_container.get_children():
		if child is BlockSlot:
			slots.append(child)

func try_add_block(upgrade: UpgradeItem) -> bool:
	# Loop through your slots to find an empty one
	for slot in slots:
		if slot.block_data == null:
			slot.set_block(upgrade)
			return true
	return false # Inventory full
