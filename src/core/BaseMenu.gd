# BaseMenu.gd
extends CanvasLayer
class_name BaseMenu

@export var back_button_paths: Array[NodePath] = []
@export var start_visible: bool = false
@export var dont_track: bool = false

func _ready():

	# Wire up any Back buttons you list in the inspector
	for path in back_button_paths:
		var btn = get_node_or_null(path)
		if btn:
			btn.pressed.connect(MenuManager.back)
