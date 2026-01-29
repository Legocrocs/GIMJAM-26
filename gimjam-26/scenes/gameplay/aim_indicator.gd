extends Node2D

@export var projectile_scene: PackedScene

@onready var line = $AimLine
@onready var pointer = $AimPointer
@onready var shoot_timer:Timer = $Timer

@export var line_length: float = 25.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_aim_indicator()
	
	if Input.is_action_pressed("shoot"):
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
	pointer.rotation = direction.angle() + deg_to_rad(90)

func shoot():
	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		
		bullet.global_position = pointer.global_position
		
		var shoot_dir = (get_global_mouse_position() - global_position).normalized()
		
		bullet.direction = shoot_dir
		bullet.rotation = shoot_dir.angle()
		
		var container = get_tree().get_first_node_in_group("projectile_group")
		
		if container:
			container.add_child(bullet)
		else:
			get_tree().current_scene.add_child(bullet)
	
