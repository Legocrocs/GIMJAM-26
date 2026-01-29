extends TextureButton

var item_data: WeaponData
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if item_data:
		set_item(item_data)

func set_item(data: WeaponData):
	if data != null:
		item_data = data
		texture_normal = data.weapon_texture
	
func _get_drag_data(at_position):
	if not item_data: return null
	
	# 1. Create the drag preview (same as InventorySlot)
	var preview = TextureRect.new()
	preview.texture = texture_normal
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40)
	set_drag_preview(preview)
	
	# 2. Return data. Note the "source" is THIS node.
	return { "source": self, "item": item_data }

# This function is called by the Inventory Slot when the drop is accepted
func on_drop_accepted():
	# If the inventory accepted the item, we destroy this world object
	get_parent().queue_free()
