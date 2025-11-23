# src/ui/main_menu.gd
extends CanvasLayer

@export var MainMenuMusic: AudioStream = preload("res://assets/Music/proto_pototo_v2.mp3")
	
func _ready() -> void:
	MenuManager.replace_menu("res://src/ui/menus/home_menu.tscn")
	call_deferred("_start_music")
	
func _start_music() -> void:
	AudioService.play_music(MainMenuMusic, 1.0, Vector2(0,0), true, "MainMenuMusic")
