# src/core/menu_manager.gd
# #################################################################################
# Manages the state and transitions of UI menus. Acts as a centralized controller
# to decouple menus from each other. Uses a stack for navigation history.
# #################################################################################
extends Node

var active_menu:
	get:
		return _menu_stack[_menu_stack.size() - 1]

# A stack of menu scene paths used to track navigation history for the "back" function.
var _menu_stack: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause()

func pause():
	if is_instance_valid(GameManager.player_instance):
		print("PAUSE")
		print(_menu_stack)
		if _menu_stack.is_empty():
			# If no other menus are open, show the pause menu.
			# Using `replace_menu` ensures the stack starts clean.
			GameManager.pause()
			push_menu("res://src/ui/menus/pause_menu.tscn")
		elif active_menu == "res://src/ui/menus/pause_menu.tscn":
			resume()
		else:
			print("BACK")
			back()
	else:
		if _menu_stack.size() > 1:
			back()

func resume():
	print("RESUME")
	# Step 1: Check if a menu needs to be closed.
	clear_history()

	# Step 2: ALWAYS resume the game.
	GameManager.resume()
		
func push_menu(menu_path: String):
	_menu_stack.push_back(menu_path)
	show_current_menu()
	pass
	
func replace_menu(menu_path: String):
	clear_history()
	push_menu(menu_path)
	pass
	
func back():
	if not _menu_stack.is_empty():
		_menu_stack.pop_back()
	show_current_menu()
	
func show_current_menu():
	hide_current_menu()
	if(_menu_stack.size() > 0):
		print(_menu_stack)
		var menu = await load(active_menu).instantiate()
		print(menu)
		get_tree().current_scene.get_node("MenuContainer").add_child(menu)
	
func hide_current_menu():
	var menu_container = get_tree().current_scene.get_node_or_null("MenuContainer")
	if menu_container:
		for child in menu_container.get_children():
			child.queue_free()

func clear_history():
	hide_current_menu()
	_menu_stack = []
