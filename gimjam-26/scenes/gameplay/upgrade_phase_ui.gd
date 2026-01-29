# upgrade_phase_ui.gd - NEW SCRIPT
extends CanvasLayer

signal confirmed
signal skipped

@onready var panel = $Panel
@onready var upgrade_container = $Panel/VBoxContainer/UpgradeContainer
@onready var confirm_button = $Panel/VBoxContainer/ConfirmButton
@onready var skip_button = $Panel/VBoxContainer/SkipButton
@onready var instruction_label = $Panel/VBoxContainer/InstructionLabel

var available_upgrades: Array[UpgradeItem] = []

func _ready():
	confirm_button.pressed.connect(_on_confirm)
	skip_button.pressed.connect(_on_skip)
	hide_ui()

func show_ui(upgrades: Array[UpgradeItem]):
	available_upgrades = upgrades
	
	# Clear previous buttons
	for child in upgrade_container.get_children():
		child.queue_free()
	
	# Create upgrade buttons
	for upgrade in upgrades:
		create_upgrade_button(upgrade)
	
	visible = true
	instruction_label.text = "Drag upgrades to grid to place blocks. Blocks will obstruct the arena!"

func create_upgrade_button(upgrade: UpgradeItem):
	var button = Button.new()
	button.text = upgrade.upgrade_name
	button.custom_minimum_size = Vector2(150, 50)
	
	button.pressed.connect(func():
		get_parent().get_node("GridOverlay").start_drag(upgrade)
	)
	
	upgrade_container.add_child(button)

func hide_ui():
	visible = false

func _on_confirm():
	confirmed.emit()

func _on_skip():
	skipped.emit()
