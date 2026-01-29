extends CharacterBody2D

@export var health: int = 30
@export var speed: float = 45
var player: Node2D = null

var damage_timer: float = 0.0
@export var damage_interval: float = 1.0 
@export var boss_corn_projectile: PackedScene

var shots_fired: int = 0
var shoot_timer: float = 0.0
@export var shoot_interval: float = 2.0

var arcs_fired: int = 0
var is_spinning: bool = false
var spin_timer: float = 0.0
var spin_duration: float = 8.0 
var spin_shoot_timer: float = 0.0
var current_spin_angle: float = 0.0

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta): 
	#if player:
		#var direction = global_position.direction_to(player.global_position)
		#velocity = direction * speed
		#move_and_slide()
		#
		#if direction.x < 0:
			#$AnimatedSprite2D.flip_h = true
		#elif direction.x > 0:
			#$AnimatedSprite2D.flip_h = false
	#else:
		#player = get_tree().get_first_node_in_group("player")
	
	damage_timer += delta
	if damage_timer >= damage_interval:
		check_for_player_damage()
		damage_timer = 0.0
	
	shoot_timer += delta
	if shoot_timer >= shoot_interval:
		shoot() # <--- YOU MUST CALL THE FUNCTION HERE
		shoot_timer = 0.0 # Reset the timer
	
	
	if is_spinning:
		process_spin_attack(delta)
		return # Stop normal movement/shooting while spinning

func check_for_player_damage():
	var overlapping_bodies = $Area2D.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(1)

func take_damage(amount: int):
	health -= amount
	modulate = Color.RED
	var original_scale = scale
	scale = original_scale * 1.2 
	
	await get_tree().create_timer(0.05).timeout
	
	# Reset visuals
	modulate = Color.WHITE
	scale = original_scale
	
	if health <= 0:
		die()

func die():
	queue_free() 



func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player": 
		if body.has_method("take_damage"):
			body.take_damage(1)


func shoot():
	if not boss_corn_projectile or not player or is_spinning:
		return
		
	shots_fired += 1
	
	if shots_fired % 3 == 0:
		fire_arc_shot()
		arcs_fired += 1
		
		if arcs_fired % 3 == 0:
			# Give the player a 1-second warning/delay
			await get_tree().create_timer(1.0).timeout 
			start_spin_attack()
	else:
		fire_single_shot()

func fire_single_shot():
	var p = boss_corn_projectile.instantiate()
	p.global_position = global_position
	p.direction = global_position.direction_to(player.global_position)
	get_tree().current_scene.add_child(p)

func fire_arc_shot():
	var base_direction = global_position.direction_to(player.global_position)
	var angle_step = PI / 8 # About 22.5 degrees between shots
	
	for i in range(-2, 3): # This runs 5 times: -2, -1, 0, 1, 2
		var p = boss_corn_projectile.instantiate()
		p.global_position = global_position
		
		# Rotate the base direction by the angle step
		var shot_direction = base_direction.rotated(i * angle_step)
		p.direction = shot_direction
		
		get_tree().current_scene.add_child(p)

func start_spin_attack():
	is_spinning = true
	spin_timer = 0.0
	current_spin_angle = 0.0 # Starts facing Up/Down

func process_spin_attack(delta):
	spin_timer += delta
	
	# TAU * 2 is 720 degrees. Dividing by spin_duration keeps the speed consistent
	current_spin_angle += ((TAU * 2) / spin_duration) * delta
	
	spin_shoot_timer += delta
	# Keep this at 0.25 to maintain the same spacing between shots
	if spin_shoot_timer >= 0.25: 
		fire_spin_projectiles(current_spin_angle)
		spin_shoot_timer = 0.0
		
	if spin_timer >= spin_duration:
		is_spinning = false
		current_spin_angle = 0.0



func fire_spin_projectiles(angle):
	# Spawning projectiles at a slower speed (80.0)
	spawn_projectile(Vector2.UP.rotated(angle), 80.0)
	spawn_projectile(Vector2.DOWN.rotated(angle), 80.0)

func spawn_projectile(dir: Vector2, custom_speed: float = 150.0):
	if boss_corn_projectile:
		var p = boss_corn_projectile.instantiate()
		p.global_position = global_position
		p.direction = dir
		
		# Set the speed on the projectile script
		if "speed" in p:
			p.speed = custom_speed
			
		get_tree().current_scene.add_child(p)
