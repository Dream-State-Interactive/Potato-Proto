# addons/id_assigner_plugin/id_assigner_plugin.gd
@tool
extends EditorPlugin

var assign_button

func _enter_tree():
	# Create a button and add it to the main editor toolbar (top of the screen).
	assign_button = Button.new()
	assign_button.text = "Assign Collectible IDs"
	assign_button.pressed.connect(on_assign_button_pressed)
	add_control_to_container(CONTAINER_TOOLBAR, assign_button)

func _exit_tree():
	# Clean up the button when the plugin is disabled.
	if is_instance_valid(assign_button):
		assign_button.queue_free()

func on_assign_button_pressed():
	# When the button is pressed, call the function in our baker script.
	# We need to get the autoloaded node first.
	var baker = get_tree().root.get_node("CollectibleBaker")
	if baker:
		baker.assign_missing_collectible_ids()
	else:
		print("Plugin Error: Could not find the CollectibleBaker autoload.")
