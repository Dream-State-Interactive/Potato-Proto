# src/ui/menus/home_menu.tscn

extends BaseMenu

@onready var quit_button = $ButtonContainer/StandardButtonQuit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	quit_button.pressed.connect(GameManager.quit)
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
