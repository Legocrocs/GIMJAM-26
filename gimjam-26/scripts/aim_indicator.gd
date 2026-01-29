extends Node2D

@export var current_weapon: WeaponData : set = _set_weapon
@onready var line = $AimLine
@onready var pointer = $AimPointer
@onready var shoot_timer:Timer = $Timer

@export var default_pointer:Texture2D
@export var line_length: float = 25.0

@export var left_weapon:WeaponData
@export var right_weapon:WeaponData

func _ready() -> void:
	if current_weapon:
		_setup_weapon()

func _set_weapon(new_weapon):
	current_weapon = new_weapon
	if is_inside_tree():
		_setup_weapon()
		
func _setup_weapon():
	if current_weapon:
		#print("DEBUG: Equipped ", current_weapon.weapon_name)
		shoot_timer.wait_time = current_weapon.fire_rate
		pointer.texture = current_weapon.weapon_texture
	else:
		pointer.texture = default_pointer
		shoot_timer.stop()
		return
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_aim_indicator()
	
	if Input.is_action_pressed("shoot") and left_weapon:
		# Quickly swap "current_weapon" context for the logic to work
		if current_weapon != left_weapon:
			current_weapon = left_weapon
			_setup_weapon()
			
		if shoot_timer.is_stopped():
			shoot()
			shoot_timer.start()

	# RIGHT CLICK LOGIC (Assumes you mapped "shoot_alt" to Right Click)
	elif Input.is_action_pressed("shoot_alt") and right_weapon:
		if current_weapon != right_weapon:
			current_weapon = right_weapon
			_setup_weapon()
			
		if shoot_timer.is_stopped():
			shoot()
			shoot_timer.start()
		
func update_aim_indicator():
	var mouse_pos = line.get_local_mouse_position()
	var direction = mouse_pos.normalized() 
	var offset = direction * line_length

	line.set_point_position(0, Vector2.ZERO)
	line.set_point_position(1, offset)
	
	pointer.position = offset
	
	if current_weapon:
		pointer.rotation = direction.angle()
		pointer.scale = Vector2(2,2)
	else:
		pointer.rotation = direction.angle() + deg_to_rad(90)
		pointer.scale = Vector2(1,1)

func shoot():
	if current_weapon:
		var root = get_tree().get_first_node_in_group("projectile_group")
		var origin = pointer.global_position
		var dir = (get_global_mouse_position() - global_position).normalized()
		
		current_weapon.activate(root, origin, dir)
		
func update_loadout(weapon_l, weapon_r):
	left_weapon = weapon_l
	right_weapon = weapon_r
	
	# Default visual to the left weapon (or hide if empty)
	if current_weapon == null or current_weapon != left_weapon:
		current_weapon = left_weapon 
		_setup_weapon()
