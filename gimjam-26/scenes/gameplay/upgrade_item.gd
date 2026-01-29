# upgrade_item.gd
class_name UpgradeItem
extends Resource

@export var upgrade_name: String = "Upgrade"
@export var description: String = ""

@export var grid_shape: Array[Vector2i] = [Vector2i(0,0)]

# FIX: Change type from Array[Vector2i] to just Array
@export var tile_pattern: Array = [Vector2i(0, 3)]  # Remove [Vector2i] type

@export var stat_type: String = "damage"
@export var stat_value: float = 10.0
