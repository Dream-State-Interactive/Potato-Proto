# src/collectibles/starch_point.gd
class_name StarchPoint extends Area2D

@export var starch_value: int = 10

func _ready():
	# Connect the Area2D's signal to this script's function
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D):
	# Check if the body that entered is the player.
	# We use 'is' keyword to check its class_name.
	if body is Player:
		# Call the player's public function to give it starch.
		body.add_starch(starch_value)
		
		# Optional: Play a sound or particle effect here.
		# ...
		
		# Destroy the starch point so it can't be collected again.
		queue_free()
