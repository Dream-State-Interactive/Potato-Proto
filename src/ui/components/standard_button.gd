extends Button

@onready var standard_button: Button = $"."
@onready var destination = get_meta("destination")
#@onready var replaceMenu = get_meta("replacementMenu")

var action

# This signal will be emitted when the button wants to open a sub-menu.
# The 'menu_path' will be the string from the 'replaceMenu' metadata.
signal menu_requested(menu_path_string)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This is a robust way to ensure the logic always runs on click.
	pressed.connect(_on_pressed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if destination and not destination.is_empty():
		MenuManager.hide_all_menus()
		SceneLoader.change_scene(destination)
	#elif replaceMenu and not replaceMenu.is_empty():
		##MenuManager.replace_menu(replaceMenu)
		#menu_requested.emit(replaceMenu)
		
func _on_button_mouse_entered() -> void:
	self.scale *= 1.1

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited() -> void:
	self.scale *= 1/1.1
