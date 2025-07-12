@tool
extends Button

@onready var standard_button: Button = $"."
@onready var destination = get_meta("destination")
@onready var replaceMenu = get_meta("ReplacementMenu")
@onready var pushMenu = get_meta("PushMenu")

var action

# This signal will be emitted when the button wants to open a sub-menu.
# The 'menu_path' will be the string from the 'replaceMenu' metadata.
signal menu_requested(menu_path_string)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This is a robust way to ensure the logic always runs on click.
	pressed.connect(_on_pressed)
	
	## Configure the pivot point to the center of the button.
	## This must be done after the node has its size determined.
	### Using await ensures this happens at the right time.
	#await resized
	#pivot_offset = size / 2.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if destination and not destination.is_empty():
		MenuManager.hide_all_menus()
		SceneLoader.change_scene(destination)
	elif replaceMenu and not replaceMenu.is_empty():
		MenuManager.replace_menu(replaceMenu)
		menu_requested.emit(replaceMenu)
	elif pushMenu and not pushMenu.is_empty():
		MenuManager.push_menu(pushMenu)
		menu_requested.emit(replaceMenu)


## ---------------------------------------------------------------------------------------------------------------
## ---- Obsolete for Scaling Buttons, but the process is handy as a reference for handing Control Pivot Origins
## ---------------------------------------------------------------------------------------------------------------
#func _on_button_mouse_entered() -> void:
	## It's better to set the scale directly rather than multiplying.
	## This avoids floating-point inaccuracies if the mouse enters/exits rapidly.
	#scale = Vector2.ONE * 1.1
#
## Reset the button scale when the mouse exits.
#func _on_button_mouse_exited() -> void:
	## Resetting to Vector2.ONE is the most stable way to return to normal size.
	#scale = Vector2.ONE
