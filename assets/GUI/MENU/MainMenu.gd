extends CanvasLayer

@export var pulse_duration: float = 2.0

@onready var title: TextureRect = $Title
@onready var button_container: Node = $VBoxContainer

# Stores the initial scale of the title set in the scene (0.3, 0.3).
var base_title_scale: Vector2

func _ready() -> void:
	# Initialize the title scale and center its pivot.
	base_title_scale = title.scale
	title.pivot_offset = title.size * 0.5
	
	# Loop through all children of the button container to configure each button.
	#for button in button_container.get_children():
		#if button is Button:
			## Center the button's pivot so that scaling occurs from the center.
			#button.pivot_offset = button.size * 0.5
			## Connect hover and press signals using inline lambda functions.
			#button.mouse_entered.connect(func() -> void: _on_button_mouse_entered(button))
			#button.mouse_exited.connect(func() -> void: _on_button_mouse_exited(button))
			#button.pressed.connect(func() -> void: _on_button_pressed(button))
	
	# Begin the pulsating animation for the title.
	animate_title()

# Recursively animate the title's scale to create a pulsing effect.
func animate_title() -> void:
	# Reset the title's scale to its base value.
	title.scale = base_title_scale
	var tween = title.create_tween()
	
	# Animate scaling up to 1.2× the base scale.
	tween.tween_property(title, "scale", base_title_scale * 1.2, pulse_duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# Animate scaling back down to the base scale.
	tween.tween_property(title, "scale", base_title_scale, pulse_duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# When the tween completes, call animate_title() again to loop the animation.
	tween.tween_callback(Callable(self, "animate_title"))

# Increase the button scale slightly when the mouse enters.
func _on_button_mouse_entered(button: Button) -> void:
	button.scale = Vector2(1.1, 1.1)

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited(button: Button) -> void:
	button.scale = Vector2(1, 1)

# Handle button press events.
func _on_button_pressed(button: Button) -> void:
	# Define configuration for each button:
	#	- "child": the name of the child TextureRect node used for visual feedback.
	#	- "scene": (optional) the scene path to load when this button is pressed.
	var button_config = {
		"Button_PLAY": { "child": "Play", "scene": "res://Scenes/Levels/main_world.tscn" },
		"Button_LEVELS": { "child": "Levels", "scene": "res://Scenes/Levels/Menus/level_select.tscn" },
		"Button_SETTINGS": { "child": "Settings" },
		"Button_QUIT": { "child": "Quit" }
	}
	
	# Check if this button has an entry in our configuration.
	if button_config.has(button.name):
		var info = button_config[button.name]
		var child_name = info["child"]
		var tex_rect = null
		
		# If a child texture is specified, retrieve it and apply a darkening effect.
		if child_name != "":
			tex_rect = button.get_node(child_name)
			if tex_rect and tex_rect is TextureRect:
				tex_rect.modulate = Color(0.7, 0.7, 0.7, 1.0)
		
		# Wait briefly (0.15 seconds) so the darkening effect is visible.
		await get_tree().create_timer(0.15).timeout
		
		# Revert the darkening effect by resetting the modulate color.
		if tex_rect:
			tex_rect.modulate = Color(1, 1, 1, 1)
		
		# Execute the corresponding action based on the button pressed.
		match button.name:
			"Button_PLAY":
				get_tree().change_scene_to_file(info["scene"])
			"Button_LEVELS":
				get_tree().change_scene_to_file(info["scene"])
			"Button_SETTINGS":
				print("Opening Settings! Wow!!! UwU")
			"Button_QUIT":
				get_tree().quit()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
