extends CharacterBody2D

@export var health: int = 5
@export var speed = 150
@onready var anim_sprite = $AnimatedSprite2D
@onready var damaged: AudioStreamPlayer2D = $damaged
@onready var death: AudioStreamPlayer2D = $death
var is_invincible: bool = false

func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	velocity = input_direction * speed

	change_state(input_direction)

func change_state(dir):
	if (dir == Vector2(0,0)):
		anim_sprite.play("idle_down")
		return
		
	if (dir.y < 0):
		anim_sprite.play("walk_up")
	elif (dir.y > 0):
		anim_sprite.play("walk_down")
	elif (dir.x != 0):
		anim_sprite.play("walk_h")
		anim_sprite.flip_h = (dir.x < 0)

func take_damage(amount: int):
	health -= amount
	print("Player Health: ", health)
	if health <= 0:
		print ("No health lmao")
		#die()
		$death.play()
	else:
		$damaged.play()

func start_invincibility():
	is_invincible = true
	# Visual feedback: Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	modulate = Color.WHITE
	is_invincible = false

func _physics_process(delta):
	get_input()
	move_and_slide()
