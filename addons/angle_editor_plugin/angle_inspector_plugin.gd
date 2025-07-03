# Filename: res://addons/angle_editor_plugin/angle_inspector_plugin.gd

## An EditorInspectorPlugin that intercepts properties in the Inspector.
## Its job is to find any float property ending in "_angle" and replace
## its default UI with our custom AnglePropertyEditor dial.
@tool
extends EditorInspectorPlugin

## A signal that is emitted when the user clicks the "Point At..." button.
## This signal is sent up to the main `plugin.gd` script, because only that
## script has access to the editor's viewport for mouse picking.
signal point_at_requested(target_node: Node2D, property_name: StringName)

## Godot asks this plugin: "Can you handle this selected object?"
## By returning 'true', we tell Godot we want to inspect every object
## to check its properties.
func _can_handle(object) -> bool:
	return true

## For every property on the object, Godot calls this function and asks:
## "Do you want to provide a custom UI for this property?"
func _parse_property(object, type, name, hint_type, hint_string, usage_flags, wide) -> bool:
	# We only care about properties that are floats and follow our naming convention.
	if type == TYPE_FLOAT and name.ends_with("_angle"):
		
		# Instantiate our custom dial UI component.
		var editor = AnglePropertyEditor.new()
		# Tell the Inspector to use our custom 'editor' for this 'name' (property).
		add_property_editor(name, editor)
		
		# As a bonus, if the object is a 2D node, add a "Point At..." button.
		if object is Node2D:
			var button = Button.new()
			button.text = "Point At..."
			# Connect the button's 'pressed' signal to our local function.
			# We use .bind() to pass along extra information: the node and property name.
			button.pressed.connect(_on_point_at_pressed.bind(object, name))
			# Add the button to the Inspector, right below the dial.
			add_custom_control(button)
			
		# Return 'true' to tell Godot: "I have handled this property.
		# Do not draw the default UI for it."
		return true
		
	# If the property doesn't match our criteria, return 'false' to let Godot
	# handle it normally.
	return false

## This function is called when the "Point At..." button is pressed.
func _on_point_at_pressed(target_node: Node2D, property_name: StringName) -> void:
	# Its only job is to emit the signal, passing the necessary information
	# up to the main plugin script for further processing.
	emit_signal("point_at_requested", target_node, property_name)
