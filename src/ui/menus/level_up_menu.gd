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
	process_mode = Node.PROCESS_MODE_ALWAYS
	print(">>> This LevelUpMenu instance: ", self)
	print(">>> _ready() CALLED | upgrades.size():", upgrades.size())

	upgrade_roll_speed_button.focus_mode = Control.FOCUS_NONE
	upgrade_grip_button.focus_mode = Control.FOCUS_NONE
	upgrade_jump_force_button.focus_mode = Control.FOCUS_NONE

	for upgrade in upgrades:
		print(">>> UpgradeData: ", upgrade.stat_identifier, upgrade.upgrade_value)

	# TEST the button references
	print(">>> Buttons valid?", upgrade_roll_speed_button, upgrade_grip_button, upgrade_jump_force_button)

	if is_instance_valid(close_menu_button):
		close_menu_button.pressed.connect(_on_close_pressed)

	connect_upgrade_buttons()
	update_ui_elements()	

# Prevents being unable to use "toggle_upgrades" after interacting with a level_up_menu button
func _input(event: InputEvent):
	if event.is_action_pressed("toggle_upgrades"):
		GUI.toggle_level_up_menu()
		get_viewport().set_input_as_handled()

func connect_upgrade_buttons():
	print(">>> FORCED BUTTON CONNECT")

	if upgrades.size() > 0:
		print("Connecting ROLL SPEED")
		upgrade_roll_speed_button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(0))
	if upgrades.size() > 1:
		print("Connecting GRIP")
		upgrade_grip_button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(1))
	if upgrades.size() > 2:
		print("Connecting JUMP")
		upgrade_jump_force_button.pressed.connect(Callable(self, "_on_upgrade_pressed").bind(2))

func _on_upgrade_pressed(index: int):
	if index >= 0 and index < upgrades.size():
		print(">>> Upgrade Button Pressed: ", upgrades[index].stat_identifier)
		on_upgrade_button_pressed(upgrades[index])
	clear_focus()

func _on_close_pressed():
	GUI.toggle_level_up_menu()

func set_initial_focus():
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		print("Resetting focus: ", focused.name)
		focused.release_focus()
	# immediately focus close button
	if is_instance_valid(close_menu_button):
		close_menu_button.grab_focus()

func clear_focus():
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		print("Clearing focus from: ", focused.name)
		focused.release_focus()

# --- PUBLIC FUNCTIONS ---
func on_upgrade_button_pressed(upgrade_data: UpgradeData):
	# Get the CURRENT cost of the upgrade right now.
	var cost = get_current_cost(upgrade_data)
	
	# Check affordability against the GameManager's source of truth.
	if GameManager.current_starch_points >= cost:
		print("Affordable! Spending points and applying upgrade for '%s'." % upgrade_data.stat_identifier)
		
		# Perform state changes via the GameManager.
		# These functions will modify the central data and emit signals.
		GameManager.spend_starch_points(cost)
		GameManager.upgrade_stat(upgrade_data.stat_identifier, upgrade_data.upgrade_value)
		
		# Immediately after the state has changed, call the UI update function.
		update_ui_elements()
		
		print("UI Updated. New Starch Points: ", GameManager.current_starch_points)
	else:
		print("Upgrade failed for '%s': Not enough Starch Points!" % upgrade_data.stat_identifier)

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
