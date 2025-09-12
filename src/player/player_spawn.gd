# src/player/player_spawn.gd
extends Node2D

var player = preload("res://src/player/player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if(!GameManager.is_player_active()):
		var playerObject = player.instantiate()
		add_child(playerObject)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
