extends CharacterBody2D

@export var health: int = 5
@export var speed = 150
@onready var anim_sprite = $AnimatedSprite2D
var is_invincible: bool = false

#@export var exit0_target_map_index: int = 1  # exit 0 goes to map 1 (change if needed)
#
#@onready var map_root := $"../Background/Maps"   # this node MUST have exit_doors + transition_to_map()
#@onready var map_layer: TileMapLayer = map_root.get_node("TileMapLayer") as TileMapLayer
#
#var _exit0_locked := false

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

func start_invincibility():
	is_invincible = true
	# Visual feedback: Flash red
	modulate = Color.RED
	await get_tree().create_timer(0.2).timeout
	modulate = Color.WHITE
	is_invincible = false
#func _check_exit0_transition() -> void:
	#if map_layer == null:
		#print("no map_layer (TileMapLayer not found)")
		#return
	#if not map_layer.has_method("transition_to_map"):
		#print("transition_to_map not found on map_layer")
		#return
	#if map_layer.exit_doors.size() <= 0:
		#print("exit_doors is empty")
		#return
#
	## Player global -> map_layer local -> cell
	#var player_cell: Vector2i = map_layer.local_to_map(map_layer.to_local(global_position))
	#var exit0_cell: Vector2i = map_layer.exit_doors[0]
#
	## Trigger once while standing on the exit tile
	#if player_cell == exit0_cell:
		#if not _exit0_locked:
			#_exit0_locked = true
			#map_layer.transition_to_map(exit0_target_map_index)
	#else:
		#_exit0_locked = false

func _physics_process(delta):
	get_input()
	move_and_slide()
	
	#_check_exit0_transition()
