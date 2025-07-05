extends Node2D

var children = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_property_list_changed() -> void:
	print("PROPERTY CHANGE")
	var numButtonsVertical = get_meta("numButtonsVertical")
	var numButtonsHorizontal = get_meta("numButtonsHorizontal")
	if(numButtonsHorizontal > 12):
		numButtonsHorizontal = 12
	if(numButtonsVertical > 12):
		numButtonsVertical = 12
	
	for i in numButtonsVertical:
		for j in numButtonsHorizontal:
			add_child($"res://assets/GUI/MENU/StandardButton.tscn")
	
