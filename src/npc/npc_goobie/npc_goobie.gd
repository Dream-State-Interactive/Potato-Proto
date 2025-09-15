extends Node2D


@onready var anim_player: AnimationPlayer = $AnimationPlayer


func _ready():
	anim_player.play("idle-loop")
