extends CharacterBody2D

@export var speed = 150
@onready var anim_sprite = $AnimatedSprite2D

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
	
func _physics_process(delta):
	get_input()
	move_and_slide()
