extends Button

@onready var standard_button: Button = $"."
@onready var destination = get_meta("destination")
@onready var replaceMenu = get_meta("replacementMenu")

var action


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_pressed() -> void:
	if(destination):
		SceneLoader.change_scene(destination)
	#elif (replaceMenu):
		#HUDLoader.replace_menu(replaceMenu)
		
func _on_button_mouse_entered() -> void:
	self.scale *= 1.1

# Reset the button scale when the mouse exits.
func _on_button_mouse_exited() -> void:
	self.scale *= 1/1.1
