extends CharacterBody2D

@export var health: int = 3
@export var speed: float = 45
var player: Node2D = null

var damage_timer: float = 0.0
@export var damage_interval: float = 1.0 

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(delta): 
	if player:
		var direction = global_position.direction_to(player.global_position)
		velocity = direction * speed
		move_and_slide()
		
		if direction.x < 0:
			$AnimatedSprite2D.flip_h = true
		elif direction.x > 0:
			$AnimatedSprite2D.flip_h = false
	else:
		player = get_tree().get_first_node_in_group("player")
	
	damage_timer += delta
	if damage_timer >= damage_interval:
		check_for_player_damage()
		damage_timer = 0.0

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
