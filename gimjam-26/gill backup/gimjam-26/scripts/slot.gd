extends TextureButton
class_name EquipSlot

var weapon_data:WeaponData = null

func set_item(new_weapon:WeaponData):
	weapon_data = new_weapon
	
	if weapon_data:
		texture_normal = weapon_data.weapon_texture
		size = Vector2(16, 16)
		tooltip_text = weapon_data.weapon_name
	else:
		texture_normal = null
		
func _get_drag_data(at_position: Vector2) -> Variant:
	if weapon_data == null:
		return null
		
	var preview = TextureRect.new()
	preview.texture = texture_normal
	preview.expand_mode = true
	preview.size = Vector2(16, 16)
	
	
	var control = Control.new()
	control.add_child(preview)
	preview.position = -0.7 * preview.get_texture().get_size()
	
	set_drag_preview(control)
	
	# Return the data we are dragging (the Weapon Resource itself)
	# You could also return a dictionary like { "source": self, "item": weapon_data }
	return { "source": self, "item": weapon_data }
	
func _can_drop_data(_at_position, data):
	# We only accept data if it has an "item" key and it is WeaponData
	return typeof(data) == TYPE_DICTIONARY and data.has("item") and data["item"] is WeaponData

func _drop_data(_at_position, data):
	var incoming_weapon = data["item"]
	var source_slot = data["source"]
	
	# Handle Swapping: If I have a weapon, send it back to the source slot
	if weapon_data != null:
		source_slot.set_item(weapon_data)
	else:
		# If I was empty, clear the source slot
		source_slot.set_item(null)
		
	# Set my new weapon
	set_item(incoming_weapon)
	
	if source_slot.has_method("on_drop_accepted"):
		source_slot.on_drop_accepted()
		
	# NOTIFY THE GAME SYSTEM (Critical Step!)
	# We'll use a signal or direct call to update the actual player inventory
	find_parent("EquipSlots").update_equipped_weapons()
