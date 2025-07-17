# src/core/menu_manager.gd
# #################################################################################
# Manages the state and transitions of UI menus. Acts as a centralized controller
# to decouple menus from each other. Uses a stack for navigation history.
# #################################################################################
extends Node

# A stack of menu scene paths used to track navigation history for the "back" function.
var _menu_stack: Array = []

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause()

func pause():
	print("PAUSE")
	print(_menu_stack)
	if _menu_stack.is_empty():
		# If no other menus are open, show the pause menu.
		# Using `replace_menu` ensures the stack starts clean.
		GameManager.pause()
		push_menu("res://src/ui/menus/pause_menu.tscn")
	elif _menu_stack[_menu_stack.size() - 1] == "res://src/ui/menus/pause_menu.tscn":
		resume()
	else:
		print("BACK")
		back()

func resume():
	print("RESUME")
	if _menu_stack.is_empty():
		# If the pause menu is visible and is the only thing in the stack, resume.
		GameManager.resume()
	else:
		# If another menu is on top (e.g., settings), act as a back button.
		back()
		
func push_menu(menu_path: String):
	_menu_stack.push_back(menu_path)
	show_current_menu()
	pass
	
func replace_menu(menu_path: String):
	clear_history()
	push_menu(menu_path)
	pass
	
func back():
	_menu_stack.pop_back()
	show_current_menu()
	
func show_current_menu():
	hide_current_menu()
	if(_menu_stack.size() > 0):
		print(_menu_stack)
		var menu = await load(_menu_stack[_menu_stack.size() - 1]).instantiate()
		print(menu)
		get_tree().current_scene.get_node("MenuContainer").add_child(menu)
	
func hide_current_menu():
	if(_menu_stack.size() > 0):
		for child in get_tree().current_scene.get_node("MenuContainer").get_children():
			child.queue_free()

func clear_history():
	_menu_stack = []
