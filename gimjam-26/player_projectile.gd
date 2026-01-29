extends Area2D

@onready var collision = $CollisionShape2D
@onready var anim = $AnimatedSprite2D
@export var speed = 100

var direction: Vector2 = Vector2.ZERO
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	position += direction * speed * delta # Moves toward the player

func _on_body_entered(body: Node2D) -> void:
	print(body)
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_timer_timeout() -> void:
	queue_free()
