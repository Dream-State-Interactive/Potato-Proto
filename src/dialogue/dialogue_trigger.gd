extends Area2D

@onready var dialogue_player: DialoguePlayer = $"../DialoguePlayer"




func _on_body_entered(body: Player) -> void:
	await dialogue_player.play()
	print("ENTERED")
	dialogue_player.play()
	$CollisionShape2D.disabled = true
