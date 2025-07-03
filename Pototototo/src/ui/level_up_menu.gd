# src/ui/level_up_menu.gd (Definitive Final Version)
extends CanvasLayer

# --- EXPORTED DATA ---
@export var upgrades: Array[UpgradeData]

# --- NODE REFERENCES ---
@onready var vbox_container = $MarginContainer/PanelContainer/VBoxContainer
@onready var close_menu_button: Button = vbox_container.get_node("CloseMenuButton")
@onready var starch_points_label = vbox_container.get_node("StarchPointsLabel")
@onready var grid_container = vbox_container.get_node("GridContainer")
@onready var upgrade_roll_speed_button: Button = grid_container.get_node("UpgradeRollSpeedButton")
@onready var upgrade_grip_button: Button = grid_container.get_node("UpgradeGripButton")
@onready var upgrade_jump_force_button: Button = grid_container.get_node("UpgradeJumpButton")

# --- GODOT FUNCTIONS ---
func _ready():
	# This property makes the menu and all its children (Buttons) immune to pause.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect button signals. This is correct and now works because of the process_mode.
	close_menu_button.pressed.connect(hide_menu)
	if upgrades.size() > 0:
		var upgrade = upgrades[0]
		upgrade_roll_speed_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))

	if upgrades.size() > 1:
		var upgrade = upgrades[1]
		upgrade_grip_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))

	if upgrades.size() > 2:
		var upgrade = upgrades[2]
		upgrade_jump_force_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))


	# Announce readiness to the GameManager.
	await get_tree().process_frame
	GameManager.on_level_up_menu_ready(self)
	
	hide_menu()

# This function receives all unhandled input events and will run even when the game is paused.
func _unhandled_input(event: InputEvent):
	# --- THIS IS THE FINAL, CORRECT FIX ---
	# 1. We ask the EVENT itself if it matches our "toggle_upgrades" action.
	# 2. We also check if 'event.pressed' is true, so this only fires on the key-down,
	#    not on the key-up (release). This correctly mimics "just_pressed" behavior.
	if event.is_action_pressed("toggle_upgrades") and event.pressed:
		if is_visible():
			hide_menu()
		else:
			open_menu()
		# Mark the event as handled to prevent any other node from processing it.
		get_viewport().set_input_as_handled()
	# ---------------------------------------------

# --- PUBLIC FUNCTIONS ---
func open_menu():
	update_ui_elements()
	show()
	get_tree().paused = true

func hide_menu():
	hide()
	get_tree().paused = false

func on_upgrade_button_pressed(upgrade_data: UpgradeData):
	var cost = upgrade_data.base_cost
	var current_starch = GameManager.current_starch_points
	
	print("--- UPGRADE ATTEMPT ---")
	print("Button for '", upgrade_data.stat_identifier, "' pressed.")
	print("Required Starch: ", cost, " | Player Has: ", current_starch)
	
	# Check if the player can afford the upgrade.
	if current_starch >= cost:
		print("Affordable! Spending points and applying upgrade...")
		GameManager.spend_starch_points(cost)
		GameManager.upgrade_stat(upgrade_data.stat_identifier, upgrade_data.upgrade_value)
		# After a successful purchase, refresh the UI.
		update_ui_elements()
	else:
		print("Upgrade failed: Not enough Starch Points!")

# A central function to update all dynamic text and button states in the menu.
func update_ui_elements():
	var current_starch = GameManager.current_starch_points
	starch_points_label.text = "Starch Points: %s" % current_starch
	
	# Get all the cost labels and buttons from the grid container.
	var cost_labels = grid_container.get_children().filter(func(c): return c.name.ends_with("CostLabel"))
	var buttons = grid_container.get_children().filter(func(c): return c is Button)

	# Loop through our data-driven upgrades and update the corresponding UI row.
	for i in range(min(buttons.size(), upgrades.size())):
		var upgrade_data = upgrades[i]
		var cost = upgrade_data.base_cost
		
		# Update the cost label for this row.
		if i < cost_labels.size():
			cost_labels[i].text = "Cost: %s" % cost
		
		# Disable the button for this row if the player can't afford it.
		buttons[i].disabled = current_starch < cost
