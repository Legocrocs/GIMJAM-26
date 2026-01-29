extends Area2D

@onready var collision = $CollisionShape2D
@onready var shoot_fireball: AudioStreamPlayer2D = $shootFireball
@export var speed = 100

var direction: Vector2 = Vector2.ZERO
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta) -> void:
	position += transform.x * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_timer_timeout() -> void:
	queue_free()
