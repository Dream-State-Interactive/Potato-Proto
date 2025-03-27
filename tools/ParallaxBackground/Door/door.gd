extends Node2D

# The amount to offset the door when opening.
@export var open_offset: Vector2 = Vector2(150, 0)
# How long the opening animation takes (in seconds)
@export var open_duration: float = 1.0

func open_door():
	print("Door is now opening!")
	# Create a tween to animate the door moving to its open position.
	var tween = create_tween()
	tween.tween_property(self, "position", position + open_offset, open_duration)
