# level_select_menu.gd
extends BaseMenu




func _ready():
	super()  # runs BaseMenu._ready(): registers, hides, wires Back
	# …now do whatever else you need, e.g. populate your level buttons…
	
## Shows the menu.
func open_menu():
	print("[LevelSelect] open_menu()")
	super() # calls BaseMenu.open_menu(self), i.e. show()

## Hides this menu and tells the GameManager to re-open the main pause menu.
func hide_menu():
	print("[LevelSelect] hide_menu()")
	super()
	#GameManager.open_pause_menu()
