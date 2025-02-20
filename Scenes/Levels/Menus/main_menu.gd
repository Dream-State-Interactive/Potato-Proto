extends Node2D

var level_select = preload("res://Scenes/Levels/Menus/level_select.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_level_select_button_pressed() -> void:
	self.remove_child($Menu)
	self.add_child(level_select.instantiate())
