extends CharacterBody2D

signal enemy_died

# Stats
@export var health: int = 3
@export var speed: float = 50.0
@export var damage: int = 1

# Movement
var move_direction: Vector2 = Vector2.ZERO
var player: CharacterBody2D = null

@onready var sprite = $Sprite2D
@onready var hitbox = $HitBox

func _ready():
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
	
	player = get_tree().get_first_node_in_group("player")
	
	if player == null:
		move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

func _physics_process(_delta):
	if player != null:
		move_direction = (player.global_position - global_position).normalized()
		
		# Kalau terlalu deket sama player, auto push away gk tau lagi cara biar gk nempel
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player < 20:  # 20 pixel threshold
			move_direction = -move_direction  # Push away
		
		if Engine.get_process_frames() % 60 == 0:
			print("Enemy moving: (%.2f, %.2f)" % [move_direction.x, move_direction.y])
	
	velocity = move_direction * speed
	
	if move_direction.x != 0:
		sprite.flip_h = move_direction.x < 0
	
	move_and_slide()

func take_damage(damage_amount: int):
	health -= damage_amount
	flash_damage()
	
	if health <= 0:
		die()

func flash_damage():
	sprite.modulate = Color(10, 10, 10)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)

func die():
	enemy_died.emit()
	queue_free()

func _on_hitbox_area_entered(area):
	if area.is_in_group("projectile"):
		print("Projectile hit!")
		take_damage(1)
		area.queue_free()
