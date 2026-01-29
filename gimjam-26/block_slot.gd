extends TextureButton
class_name BlockSlot

var block_data: UpgradeItem = null

func set_block(upgrade: UpgradeItem):
	block_data = upgrade
	
	if block_data:
		# Assuming UpgradeItem has an 'icon' or we use a default
		# You might need to add 'icon' to UpgradeItem resource
		texture_normal = load("res://path/to/default_block_icon.png") 
		tooltip_text = block_data.upgrade_name
	else:
		texture_normal = null
		tooltip_text = "Empty"

func _get_drag_data(_at_position):
	if not block_data: return null
	
	# Visual Preview
	var preview = TextureRect.new()
	preview.texture = texture_normal
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(40, 40)
	set_drag_preview(preview)
	
	# Data Payload
	return { "source": self, "block": block_data }

# Called by GridOverlay when placement is successful
func consume_block():
	set_block(null)
