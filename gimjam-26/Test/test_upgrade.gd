# test_upgrade.gd
extends Node2D

@onready var upgrade_screen = $UpgradeScreen

func _ready():
	upgrade_screen.upgrades_confirmed.connect(_on_upgrades_confirmed)
	upgrade_screen.show()

func _on_upgrades_confirmed():
	print("=== UPGRADES CONFIRMED ===")
	print("Blocked cells: ", GridManager.get_blocked_cells())
	print("Total upgrades: ", GridManager.placed_upgrades.size())
	
	for data in GridManager.placed_upgrades:
		print("  - ", data.upgrade.upgrade_name, " at ", data.position)
