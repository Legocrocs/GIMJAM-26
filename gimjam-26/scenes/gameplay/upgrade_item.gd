class_name UpgradeItem
extends Resource

@export_group("Visuals")
@export var upgrade_name: String = "Block"
@export var icon: Texture2D # <-- The texture seen in inventory/world
@export var color: Color = Color.WHITE # Optional: Tint the block

@export_group("Grid Data")
# The shape of the block on the grid (e.g., [[0,0], [1,0]] for 2-wide)
@export var grid_shape: Array[Vector2i] = [Vector2i(0,0)]
# The atlas coordinates for the tiles placed in the world
@export var tile_pattern: Array = [Vector2i(3, 4)]
