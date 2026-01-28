extends CharacterBody2D

@export var health: int = 3
@export var speed: float = 45
var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")

func _physics_process(_delta):
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


func take_damage(amount: int):
	health -= amount
	
	# Optional: make the enemy blink when hit
	modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
	
	if health <= 0:
		die()

func die():
	queue_free() 


# Only proceed if the body we hit is the Player
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player": 
		print("Signal Player Collision")
		if body.has_method("take_damage"):
			body.take_damage(1)
