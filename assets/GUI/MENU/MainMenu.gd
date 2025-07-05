extends CanvasLayer

# @onready var button_container: Node = $VBoxContainer

func _ready() -> void:
	# Loop through all children of the button container to configure each button.
	#for button in button_container.get_children():
		#if button is Button:
			## Center the button's pivot so that scaling occurs from the center.
			#button.pivot_offset = button.size * 0.5
			## Connect hover and press signals using inline lambda functions.
			#button.mouse_entered.connect(func() -> void: _on_button_mouse_entered(button))
			#button.mouse_exited.connect(func() -> void: _on_button_mouse_exited(button))
			#button.pressed.connect(func() -> void: _on_button_pressed(button))
	SettingsService.initializeSettings()

# Increase the button scale slightly when the mouse enters.
func _on_button_mouse_entered(button: Button) -> void:
	button.scale = Vector2(1.1, 1.1)

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited(button: Button) -> void:
	button.scale = Vector2(1, 1)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
