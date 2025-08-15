# src/core/menu_manager.gd
# #################################################################################
# Manages the state and transitions of UI menus. Acts as a centralized controller
# to decouple menus from each other. Uses a stack for navigation history.
# #################################################################################
extends Node

signal show_menu_requested(menu_path)
signal hide_all_menus_requested

var active_menu:
	get:
		return _menu_stack[_menu_stack.size() - 1]

# A stack of menu scene paths used to track navigation history for the "back" function.
var _menu_stack: Array = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func pause():
	if is_instance_valid(GameManager.player_instance):
		if _menu_stack.is_empty():
			# If no other menus are open, show the pause menu.
			# Using `replace_menu` ensures the stack starts clean.
			GameManager.pause()
			push_menu("res://src/ui/menus/pause_menu.tscn")
		else:
			back()
	else:
		if _menu_stack.size() > 1:
			back()

func resume():
	clear_history()
	GameManager.resume()
		
func push_menu(menu_path: String):
	_menu_stack.push_back(menu_path)
	show_menu_requested.emit(active_menu) # SIGNAL (rc/core/gui_manager.gd)
	#show_current_menu()
	
func replace_menu(menu_path: String):
	clear_history()
	push_menu(menu_path)
	
func back():
	if not _menu_stack.is_empty():
		_menu_stack.pop_back()
	
	if not _menu_stack.is_empty():
		show_menu_requested.emit(active_menu)
	else:
		hide_all_menus_requested.emit() # SIGNAL (rc/core/gui_manager.gd)
		if get_tree().paused:
			GameManager.resume()
	
#func show_current_menu():
	#hide_current_menu()
	#if(_menu_stack.size() > 0):
		#print(_menu_stack)
		#var menu = await load(active_menu).instantiate()
		#print(menu)
		#GUI.get_node("MenuContainer").add_child(menu)
	##
#func hide_current_menu():
	#var menu_container = GUI.get_node_or_null("MenuContainer")
	#if menu_container:
		#for child in menu_container.get_children():
			#child.queue_free()

func clear_history():
	hide_all_menus_requested.emit() # SIGNAL (rc/core/gui_manager.gd)
	_menu_stack = []
