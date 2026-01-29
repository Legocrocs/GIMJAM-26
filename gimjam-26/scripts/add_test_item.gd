extends Area2D

@export var item_scene: PackedScene # Assign WorldItem.tscn here
@export var loot_table: Array[WeaponData] # Drag your weapon resources here
@export var player_pos: PackedScene

func spawn_random_drop():
	# 1. Instantiate the World Item container
	var drop = item_scene.instantiate()
	
	# 2. Pick a random weapon
	var random_weapon = loot_table.pick_random()
	
	# 3. Position it near the player (or at mouse)
	# Assuming you have a reference to the player, or use global mouse pos
	var spawn_pos = get_tree().get_first_node_in_group("Player").position
	drop.position = spawn_pos
	print(drop.position)
	# 4. Add to the scene ("ProjectileContainer" or just current scene)
	get_tree().current_scene.add_child(drop)
	
	# 5. Configure the button inside (We need to reach the TextureButton child)
	# Assuming TextureButton is the first child or named "TextureButton"
	drop.get_node("TextureButton").set_item(random_weapon)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_P:
			
		#print("mouse in area")
		#print("spawn item")
			spawn_random_drop()
