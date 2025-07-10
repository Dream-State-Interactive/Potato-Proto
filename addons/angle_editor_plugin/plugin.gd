# Filename: res://addons/angle_editor_plugin/plugin.gd

@tool
extends EditorPlugin

# This plugin's only job is to load the Inspector part of our addon
# and handle the logic for the "Point At..." button.
var inspector_plugin

# --- State management is now ONLY for the "Point At..." feature ---
var _point_at_target: Node2D = null
var _point_at_property: StringName


func _enter_tree() -> void:
	# Instantiate the inspector plugin.
	inspector_plugin = preload("res://addons/angle_editor_plugin/angle_inspector_plugin.gd").new()
	
	# Connect to its signal BEFORE adding it to the editor.
	inspector_plugin.point_at_requested.connect(activate_point_at_mode)
	
	# Now, add the plugin.
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	if inspector_plugin:
		# Disconnect the signal for clean removal.
		if inspector_plugin.is_connected("point_at_requested", activate_point_at_mode):
			inspector_plugin.point_at_requested.disconnect(activate_point_at_mode)
		remove_inspector_plugin(inspector_plugin)


# This function is called by the signal from the inspector plugin.
func activate_point_at_mode(target: Node2D, prop_name: StringName) -> void:
	_point_at_target = target
	_point_at_property = prop_name


# This is now much simpler. The plugin only needs to handle input
# when it is actively in "point at" mode.
func _handles(object) -> bool:
	return _point_at_target != null


# This function is now much simpler. It only contains the "Point At" logic.
func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _point_at_target and event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		var viewport = get_editor_interface().get_editor_viewport_2d()
		var click_pos = viewport.get_global_transform().affine_inverse() * event.position
		var angle_rad = (click_pos - _point_at_target.global_position).angle()
		var angle_deg = rad_to_deg(angle_rad)
		
		var undo_redo = get_editor_interface().get_undo_redo()
		undo_redo.create_action("Set " + _point_at_property)
		undo_redo.add_do_property(_point_at_target, _point_at_property, angle_deg)
		undo_redo.add_undo_property(_point_at_target, _point_at_property, _point_at_target.get(_point_at_property))
		undo_redo.commit_action()
		
		get_editor_interface().get_inspector().refresh()
		
		# Reset the state so we don't handle any more input.
		_point_at_target = null
		_point_at_property = ""
		
		return true # Consume the event.

	# All legacy drag handle logic has been removed.
	return false
