# src/core/gui_manager.gd
extends CanvasLayer
class_name GameGUI

# --- Preload the scenes this manager is responsible for ---
const HUD = preload("res://src/ui/hud/hud.tscn")
const LEVEL_UP_MENU = preload("res://src/ui/menus/level_up_menu.tscn")

@onready var GUI_root = $"."
@onready var menu_container: CanvasLayer = $MenuContainer
@onready var menu_backdrop_container: CanvasLayer = $MenuBackdropContainer
var hud_instance: CanvasLayer 
var level_up_menu_instance: CanvasLayer
var _overlay: ColorRect

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GUI RUNNING")
	hud_instance = HUD.instantiate()
	add_child(hud_instance)
	hud_instance.hide()

	level_up_menu_instance = LEVEL_UP_MENU.instantiate()
	add_child(level_up_menu_instance)
	level_up_menu_instance.hide()
	print(">>> LevelUpMenu instantiated in GUI: ", level_up_menu_instance)
	await self.ready
	
	MenuManager.show_menu_requested.connect(_on_show_menu_requested)
	MenuManager.hide_all_menus_requested.connect(_on_hide_all_menus_requested)
	
	# Listen for when the player has been registered by the GameManager.
	GameManager.player_is_ready.connect(_on_player_is_ready)
	# Listen for when we leave the game world.
	GameManager.scene_changed.connect(_on_leaving_game_world)
	# Listen for when a stat is upgraded
	GameManager.stat_upgraded.connect(_on_stat_upgraded)

func _unhandled_input(event: InputEvent):
	# Handle the Pause action.
	# We just pass the request to the MenuManager, which already has all the logic.
	if event.is_action_pressed("pause"):
		MenuManager.pause()
		# We use accept_event() to stop the input from propagating further,
		# preventing any other node (like the player) from also reacting to it.
		get_viewport().set_input_as_handled()

	# Handle the Level Up Menu action.
	if event.is_action_pressed("toggle_upgrades"):
		# We add the critical check here: DO NOT open the level-up menu
		# if the game is already paused by something else (like the main pause menu).
		if get_tree().paused:
			# Optional: print a message to know why it's not opening
			# print("Blocked opening Level Up Menu because game is paused.")
			return

		# If not paused, proceed with the normal toggle logic.
		toggle_level_up_menu()
		get_viewport().set_input_as_handled()

func toggle_level_up_menu():
	# Prevent level_up_menu from being opened in Main Menu.
	if not is_instance_valid(GameManager.player_instance) or not GameManager.player_stats:
		print("LevelUpMenu blocked: No valid player or stats.")
		return
	# Called by the Player. 
	if level_up_menu_instance.is_visible():
		level_up_menu_instance.hide()
		GameManager.resume()
	else:
		# Don't open if the main pause menu is up.
		if get_tree().paused: return
		level_up_menu_instance.show()
		# Refresh the UI with the latest costs and stats every time it's opened.
		if level_up_menu_instance.has_method("update_ui_elements"):
			level_up_menu_instance.update_ui_elements()
		GameManager.pause()
		
		# Reset keyboard focus on menu open
		await get_tree().process_frame
		level_up_menu_instance.set_initial_focus()

func show_pause_menu_backdrop():
	if _overlay and is_instance_valid(_overlay):
		return
	_overlay = ColorRect.new()
	_overlay.color = Color(0.07, 0.07, 0.07, 0.60)
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # swallows clicks
	_overlay.z_index = 0

	# Make it fill the screen
	_overlay.anchor_left = 0
	_overlay.anchor_top = 0
	_overlay.anchor_right = 1
	_overlay.anchor_bottom = 1
	_overlay.offset_left = 0
	_overlay.offset_top = 0
	_overlay.offset_right = 0
	_overlay.offset_bottom = 0

	menu_backdrop_container.add_child(_overlay)

func hide_pause_menu_backdrop():
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null


# --- Signals ---

# MenuManager will request this to show a menu.
func _on_show_menu_requested(menu_path: String):
	# Clear whatever menu is currently visible.
	for child in menu_container.get_children():
		child.queue_free()
	
	# Load and add the new menu scene.
	var menu_scene = await load(menu_path).instantiate()
	menu_container.add_child(menu_scene)
	hud_instance.hide()

# This function reacts to the MenuManager's request to hide everything.
func _on_hide_all_menus_requested():
	for child in menu_container.get_children():
		child.queue_free()
	hud_instance.show()

func _on_player_is_ready(player_node: Player):
	print("GUI: Player is ready. Connecting HUD.")
	# Show the HUD and connect it.
	hud_instance.show()
	hud_instance.connect_to_game_manager_signals()

func _on_leaving_game_world():
	print("GUI: Leaving game world. Hiding HUD.")
	# When the SceneLoader tells us we are leaving the level, hide the in-game UI.
	hud_instance.hide()
	level_up_menu_instance.hide()
	## Re-connect the signal so the HUD will show up again next time we enter a level.
	#if not GameManager.player_health_updated.is_connected(_on_player_registered):
		#GameManager.player_health_updated.connect(_on_player_registered)

func _on_stat_upgraded(stat_name: String):
	# Tell the level up menu to refresh itself.
	if is_instance_valid(level_up_menu_instance) and level_up_menu_instance.is_visible():
		level_up_menu_instance.update_ui_elements()
