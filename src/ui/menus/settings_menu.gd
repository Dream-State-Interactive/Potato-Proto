# settings_menu.gd
extends BaseMenu

# In the Inspector:
#  - set start_visible = false
#  - point back_button_paths = [ "MarginContainer/PanelContainer/VBoxContainer/BackButton" ]

func _ready():
	super()            # runs BaseMenu._ready()
	process_mode = PROCESS_MODE_ALWAYS
	# (any extra init here)

func hide_menu():
	super.hide_menu()
