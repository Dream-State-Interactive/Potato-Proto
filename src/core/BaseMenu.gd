# BaseMenu.gd
extends CanvasLayer
class_name BaseMenu

@export var back_button_paths: Array[NodePath] = []
@export var start_visible: bool = false
@export var dont_track: bool = false

func _ready():
	# Always register / unregister
	MenuManager.register_menu(self)
	if start_visible:
		show()
	else:
		hide()

	# Wire up any Back buttons you list in the inspector
	for path in back_button_paths:
		var btn = get_node_or_null(path)
		if btn:
			btn.pressed.connect(MenuManager.back)

func open_menu():
	show()

func hide_menu():
	if MenuManager._current_menu_path == scene_file_path:
		MenuManager._current_menu_path = ""
	hide()


func _exit_tree():
	MenuManager.unregister_menu(self)
