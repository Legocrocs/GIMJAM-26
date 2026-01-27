extends Area2D

@onready var collision = $CollisionShape2D
@export var speed = 100
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	if not is_in_group("projectile"):
		add_to_group("projectile")
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta) -> void:
	position += transform.x * speed * delta

func _on_area_entered(area):
	var parent = area.get_parent()
	if parent and (parent.name == "Enemy" or parent.is_in_group("enemies")):
		queue_free()
	elif area.is_in_group("enemies"):
		queue_free()

func _on_body_entered(body):
	queue_free()

func _on_timer_timeout() -> void:
	queue_free()
