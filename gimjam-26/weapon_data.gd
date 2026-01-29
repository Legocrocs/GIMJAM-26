extends Resource
class_name WeaponData

@export_group("Visuals")
@export var weapon_name:String

@export_group("Stats")
@export var projectile_scene:PackedScene
@export var fire_rate:float
@export var projectile_per_shot:int
@export var spread_deg:float
