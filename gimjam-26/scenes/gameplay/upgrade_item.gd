# upgrade_item.gd
class_name UpgradeItem
extends Resource

@export var upgrade_name: String = "Upgrade"
@export var description: String = ""

# Shape dalam grid logic
@export var grid_shape: Array[Vector2i] = [Vector2i(0,0)]

# Tile coords untuk setiap cell dalam shape
# Index array harus match dengan grid_shape
@export var tile_pattern: Array[Vector2i] = [Vector2i(0, 3)]

# Stats
@export var stat_type: String = "damage"
@export var stat_value: float = 10.0
