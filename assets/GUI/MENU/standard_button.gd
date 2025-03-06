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
		get_tree().change_scene_to_file(destination)
	#elif (load(replaceMenu)):
		#self.remove_child($Menu)
		#self.add_child(replaceMenu.instantiate())
