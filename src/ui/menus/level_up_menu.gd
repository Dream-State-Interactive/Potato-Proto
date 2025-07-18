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

	if upgrades.size() > 0:
		var upgrade = upgrades[0]
		upgrade_roll_speed_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))

	if upgrades.size() > 1:
		var upgrade = upgrades[1]
		upgrade_grip_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))

	if upgrades.size() > 2:
		var upgrade = upgrades[2]
		upgrade_jump_force_button.pressed.connect(func(): on_upgrade_button_pressed(upgrade))
	
	MenuManager.back()
	

# This function receives all unhandled input events and will run even when the game is paused.
func _unhandled_input(event: InputEvent):
	print("Upgrade toggle check — pause visible?: ", GameManager.game_paused)
	# --- THIS IS THE FINAL, CORRECT FIX ---
	# 1. We ask the EVENT itself if it matches our "toggle_upgrades" action.
	# 2. We also check if 'event.pressed' is true, so this only fires on the key-down,
	#    not on the key-up (release). This correctly mimics "just_pressed" behavior.
	if GameManager.game_paused:
		return
	if event.is_action_pressed("toggle_upgrades") and event.pressed:
		if is_visible():
			MenuManager.back()
		else:
			MenuManager.push_menu("res://src/ui/menus/level_up_menu.tscn")
		# Mark the event as handled to prevent any other node from processing it.
		get_viewport().set_input_as_handled()
	# ---------------------------------------------

# --- PUBLIC FUNCTIONS ---
func on_upgrade_button_pressed(upgrade_data: UpgradeData):
	var cost = get_current_cost(upgrade_data)
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
		var cost = get_current_cost(upgrade_data)
		
		# Update the cost label for this row.
		if i < cost_labels.size():
			cost_labels[i].text = "Cost: %s" % cost
		
		# Disable the button for this row if the player can't afford it.
		buttons[i].disabled = current_starch < cost

# This function calculates the current cost of an upgrade dynamically.
func get_current_cost(upgrade_data: UpgradeData) -> int:
	# --- THIS IS THE CORRECTED LOGIC ---
	var current_stat_value: float = 0.0
	var default_stat_value: float = 0.0

	# 1. Get the player's CURRENT value for this stat.
	# We use the 'in' keyword to check if the property exists on the object before getting it.
	if upgrade_data.stat_identifier in GameManager.player_stats:
		current_stat_value = GameManager.player_stats.get(upgrade_data.stat_identifier)
	else:
		push_warning("Stat '%s' not found in player_stats!" % upgrade_data.stat_identifier)
		return 99999 # Return a high cost to prevent purchase if misconfigured.

	# 2. Get the DEFAULT value for this stat from our clean resource.
	if upgrade_data.stat_identifier in GameManager.DEFAULT_STATS:
		default_stat_value = GameManager.DEFAULT_STATS.get(upgrade_data.stat_identifier)
	else:
		push_warning("Stat '%s' not found in DEFAULT_STATS resource!" % upgrade_data.stat_identifier)
		return 99999
	
	# ----------------------------------------
	
	# 3. Calculate how many times this stat has been upgraded.
	# Use max(0, ...) to prevent negative levels if a stat can be reduced.
	# Use roundi() to handle potential floating point inaccuracies.
	if upgrade_data.upgrade_value == 0:
		push_warning("UpgradeData for '%s' has an upgrade_value of 0!" % upgrade_data.stat_identifier)
		return 99999

	var upgrade_levels_purchased = roundi(max(0, (current_stat_value - default_stat_value) / upgrade_data.upgrade_value))
	
	# 4. Calculate the final cost.
	var current_cost = upgrade_data.base_cost + (upgrade_levels_purchased * upgrade_data.cost_increase_per_level)
	
	
	return current_cost
