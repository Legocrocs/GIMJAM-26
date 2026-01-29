extends Resource
class_name WeaponData

@export_group("Visuals")
@export var weapon_name:String
@export var weapon_texture:Texture2D

@export_group("Stats")
@export var projectile_scene:PackedScene
@export var fire_rate:float
@export var projectile_per_shot:int
@export var projectile_speed:float
@export var spread:float
@export var lifetime:float
@export var damage:float

func activate(root_node: Node, origin: Vector2, direction: Vector2):
	spawn_projectile(root_node, origin, direction)
	
func spawn_projectile(root_node: Node, origin: Vector2, direction: Vector2):
	if not projectile_scene:  
		print("none") 
		return

	var bullet = projectile_scene.instantiate()
	bullet.global_position = origin
	
	if "speed" in bullet:
		bullet.speed = projectile_speed
		
	if "lifetime" in bullet:
		bullet.lifetime = lifetime
		
	if "fire_rate" in bullet:
		bullet.fire_rate = fire_rate

	if "spread" in bullet:
		bullet.spread = spread
		
	if "damage" in bullet:
		bullet.damage = damage
		
	if "direction" in bullet:
		bullet.direction = direction
		bullet.rotation = direction.angle()

	#for prop in bullet.get_property_list():
		#print(prop.name)
	root_node.add_child(bullet)
