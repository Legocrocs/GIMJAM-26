extends Area2D

@onready var collision = $CollisionShape2D
@onready var anim = $AnimatedSprite2D
var speed = 1
var lifetime = 1.0
var direction: Vector2 = Vector2.RIGHT
var fire_rate:float = 1
#var anims = ["var1", "var2", "var3", "var_water"]
# Called when the node enters the scene tree for the first time.
func _ready() -> void:

	anim.play("var_water")
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta) -> void:
	position += transform.x * speed * delta

func _on_timer_timeout() -> void:
	queue_free()
