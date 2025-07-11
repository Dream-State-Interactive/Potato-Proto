# src/core/menu_manager.gd
# #################################################################################
# Manages the state and transitions of UI menus. Acts as a centralized controller
# to decouple menus from each other. Uses a stack for navigation history.
# #################################################################################
extends Node

# Registry of all active menu instances, keyed by their scene file path.
var _registered_menus: Dictionary = {}

# A stack of menu scene paths used to track navigation history for the "back" function.
var _menu_stack: Array = []

# Tracks the path of the currently displayed menu.
# NOTE: This implementation primarily relies on the `.visible` property instead.
var _current_menu_path: String = ""


# Adds a menu instance to the registry. Called by menus in `_ready()`.
func register_menu(menu_instance):
	if menu_instance and menu_instance.scene_file_path != "":
		_registered_menus[menu_instance.scene_file_path] = menu_instance

# Removes a menu instance from the registry. Called by menus in `_exit_tree()`.
func unregister_menu(menu_instance):
	var path = menu_instance.scene_file_path
	if _registered_menus.has(path):
		_registered_menus.erase(path)

# Helper function to remove any registered menus that are no longer valid instances.
# Prevents errors from accessing freed nodes.
func _cleanup_invalid():
	# Iterate over a copy of keys to allow safe removal during iteration.
	for path in _registered_menus.keys().duplicate():
		var menu = _registered_menus[path]
		if not is_instance_valid(menu):
			_registered_menus.erase(path)

# Hides the currently visible menu and displays a new one.
# The hidden menu's path is pushed to the `_menu_stack` for history.
func replace_menu(new_menu_path: String):
	_cleanup_invalid()

	# Step 1: Find and hide the currently visible menu.
	for path in _registered_menus.keys():
		var menu = _registered_menus[path]
		
		# Skip potentially invalid instances that were not caught by cleanup.
		if not is_instance_valid(menu):
			continue
		
		# Assumes only one menu is visible at a time.
		if menu.visible:
			# Hide the menu, preferring its own `hide_menu` method if available.
			if menu.has_method("hide_menu"):
				menu.hide_menu()
			else:
				menu.visible = false
			
			# Add the hidden menu's path to the history stack.
			_menu_stack.push_back(path)
			
			# Exit loop once the visible menu has been handled.
			break

	# Step 2: Display the new menu.
	_show_menu(new_menu_path)

# Internal function to show a menu specified by its scene path.
func _show_menu(path: String):
	if _registered_menus.has(path):
		var menu_to_show = _registered_menus[path]
		
		if not is_instance_valid(menu_to_show):
			push_error("MenuManager: registered menu freed unexpectedly: " + path)
			return
		
		# Only set _current_menu_path if the menu WANTS to be tracked (i.e., dont_track == false)
		if not menu_to_show.has_meta("dont_track") or not menu_to_show.dont_track:
			_current_menu_path = path
		
		# Use the menu's `open_menu` method if it exists for custom open logic,
		# otherwise, just set its visibility to true.
		if menu_to_show.has_method("open_menu"):
			menu_to_show.open_menu()
		else:
			menu_to_show.visible = true
	else:
		push_error("MenuManager: No menu registered for " + path)


# Hides the current menu and displays the previous menu from the history stack.
func back():
	_cleanup_invalid()

	# The old implementation looped through all menus and hid the FIRST one it found that was visible.
	# This is unreliable when multiple menus are visible (I.E. when using push_menu).
	# The fix is specifically hiding the menu so it's tracked as the "current" one.

	# Step 1: Find and hide the currently active menu using its tracked path.
	if _current_menu_path != "" and _registered_menus.has(_current_menu_path):
		var current_menu = _registered_menus[_current_menu_path]
		if is_instance_valid(current_menu):
			if current_menu.has_method("hide_menu"):
				current_menu.hide_menu()
			else:
				# Fallback just in case
				current_menu.hide()
	else:
		# This case can be triggered if back() is called when no menu is "current".
		# Add a warning for debugging.
		push_warning("MenuManager.back() called, but no _current_menu_path is set.")


	# Step 2: Pop the last path from the history stack and show that menu.
	if _menu_stack.is_empty():
		push_warning("MenuManager: Back stack empty. No menu to return to.")
		# After hiding the current menu, there's nothing else to show. NOTHING.
		# Clear the current path since we're at the bottom of the stack.
		_current_menu_path = ""
		return
	
	var previous_menu_path = _menu_stack.pop_back()
	_show_menu(previous_menu_path) # Show the previous menu and set it as current.


# if you want to layer a Menu over another Menu (instead of replace), use push_menu() instead of replace_menu()
# This makes the current menu remain open and overlay the new one
func push_menu(new_menu_path: String):
	_cleanup_invalid()

	# Find and store currently visible menu without hiding it
	for path in _registered_menus.keys():
		var menu = _registered_menus[path]
		if is_instance_valid(menu) and menu.visible:
			# Notify the underlying menu that it is being covered by a child menu.
			# This allows it to hide its interactive elements without hiding itself entirely.
			if menu.has_method("on_child_menu_opened"):
				menu.on_child_menu_opened()
				
			_menu_stack.push_back(path)
			break

	# Show the new menu on top
	_show_menu(new_menu_path)
	print("→ stack after push:", _menu_stack)


# Hides all registered menus and clears the navigation history stack.
# Useful for major state changes, like returning to the main menu from a game level.
func hide_all_menus():
	_cleanup_invalid()
	for path in _registered_menus.keys():
		var menu = _registered_menus[path]
		if is_instance_valid(menu) and menu.visible:
			if menu.has_method("hide_menu"):
				menu.hide_menu()
			else:
				menu.hide()
	_menu_stack.clear()
	_current_menu_path = ""
