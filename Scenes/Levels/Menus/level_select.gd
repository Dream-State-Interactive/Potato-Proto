extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_level_1_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/proto/level_1_proto.tscn")


func _on_level_2_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/main_world.tscn")


func _on_level_3_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/main_world.tscn")


func _on_level_4_button_pressed() -> void:
	pass # Replace with function body.
