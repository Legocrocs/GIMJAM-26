# inventory_ui.gd - UPDATED
extends Control

@onready var item_container = $Panel/VBoxContainer/ItemContainer

var inventory_items: Array[UpgradeData] = []

signal item_drag_started(upgrade_data: UpgradeData)

func _ready():
	visible = true
	# Add to group so item_dropped can find it
	add_to_group("UpgradeInventory")

func add_upgrade(upgrade_data: UpgradeData):
	inventory_items.append(upgrade_data)
	create_inventory_slot(upgrade_data)
	print("Added to upgrade inventory: ", upgrade_data.upgrade_name)

func create_inventory_slot(upgrade_data: UpgradeData):
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(80, 80)
	
	var vbox = VBoxContainer.new()
	slot.add_child(vbox)
	
	# Icon
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(60, 60)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.texture = upgrade_data.upgrade_icon
	vbox.add_child(icon)
	
	# Label
	var label = Label.new()
	label.text = upgrade_data.upgrade_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	# Drag button
	var button = Button.new()
	button.text = "Use"
	button.pressed.connect(func(): start_drag_item(upgrade_data, slot))
	vbox.add_child(button)
	
	item_container.add_child(slot)

func start_drag_item(upgrade_data: UpgradeData, slot: Panel):
	print("Starting drag: ", upgrade_data.upgrade_name)
	
	# Convert UpgradeData → UpgradeItem for grid system
	var upgrade_item = UpgradeItem.new()
	upgrade_item.upgrade_name = upgrade_data.upgrade_name
	upgrade_item.grid_shape = upgrade_data.grid_shape
	upgrade_item.tile_pattern = upgrade_data.tile_pattern
	
	item_drag_started.emit(upgrade_item)
	
	# Remove from inventory
	inventory_items.erase(upgrade_data)
	slot.queue_free()
