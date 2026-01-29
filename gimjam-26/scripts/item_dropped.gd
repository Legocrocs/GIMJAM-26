extends TextureButton

var item_data: WeaponData
var player_in_range: bool = false # The "Switch"
var target_inventory = null # Store the inventory so we don't have to find it every frame

@onready var prompt_label = $"../PickupArea/Label"
@onready var pickup_area = $"../PickupArea"

func _ready() -> void:
	if item_data:
		set_item(item_data)
	
	# Connect signals via code to be safe
	# We connect BOTH body_entered (for CharacterBody2D) and area_entered (for Area2D)
	if pickup_area:
		pickup_area.body_entered.connect(_on_body_entered)
		pickup_area.body_exited.connect(_on_body_exited)
		pickup_area.area_entered.connect(_on_area_entered)
		pickup_area.area_exited.connect(_on_area_exited)
	
	if prompt_label:
		prompt_label.visible = false

func set_item(data: WeaponData):
	if data != null:
		item_data = data
		texture_normal = data.weapon_texture

# --- THE "SWITCH" LOGIC ---

# 1. Player Walked IN
func _on_body_entered(body: Node):
	if body.is_in_group("Player"):
		player_in_range = true
		if prompt_label: prompt_label.visible = true
		# Find inventory now so we are ready to add
		target_inventory = get_tree().get_first_node_in_group("PlayerInventory")
		print(get_tree().get_first_node_in_group("PlayerInventory").name)
# 2. Player Walked OUT
func _on_body_exited(body: Node):
	if body.is_in_group("Player"):
		player_in_range = false
		if prompt_label: prompt_label.visible = false
		target_inventory = null

# (Optional) If your player detects via Area2D instead of Body
func _on_area_entered(area: Area2D):
	if area.get_parent().is_in_group("Player") or area.is_in_group("Player"):
		# Reuse the same logic
		_on_body_entered(area.get_parent()) # Or area, depending on your structure

func _on_area_exited(area: Area2D):
	if area.get_parent().is_in_group("Player") or area.is_in_group("Player"):
		_on_body_exited(area.get_parent())

# --- THE INPUT CHECK ---

func _unhandled_input(event):
	# This runs every time a key is pressed.
	# We only care if the "Switch" (player_in_range) is ON.
	if player_in_range and event.is_action_pressed("interact"):
		attempt_pickup()

func attempt_pickup():
	print(target_inventory)
	if target_inventory and item_data:
		# Use the helper function we made in EquipSlots
		if target_inventory.has_method("try_add_item"): 
			print("yes") 
		else: 
			print("no")
		var success = target_inventory.try_add_item(item_data)
		
		if success:
			on_drop_accepted() # Delete item
		else:
			print("Inventory is full!")

# --- DRAG AND DROP (Keep existing) ---
func _get_drag_data(_at_position):
	if not item_data: return null
	var preview = TextureRect.new()
	preview.texture = texture_normal
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(16, 16)
	set_drag_preview(preview)
	return { "source": self, "item": item_data }

func on_drop_accepted():
	get_parent().queue_free()
