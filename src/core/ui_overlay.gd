extends CanvasLayer

@onready var save_load_menu = $SaveLoadMenu
@onready var settings_menu = $SettingsMenu
@onready var level_select: CanvasLayer = $LevelSelect

func _ready():
	# Register these so MenuManager can hide/show them:
	MenuManager.register_menu(save_load_menu)
	MenuManager.register_menu(settings_menu)
	MenuManager.register_menu(level_select)

	# Start hidden
	save_load_menu.hide()
	settings_menu.hide()
	level_select.hide()
	print("[UIOverlay] registered menus:", MenuManager._registered_menus.keys())
