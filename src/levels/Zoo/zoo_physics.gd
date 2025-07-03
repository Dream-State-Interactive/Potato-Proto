extends Node2D

func _input(event):
	if event.is_action_pressed("jump"):
		var collisionmaker = $Collisionmaker
		var rb: RigidBody2D = null
		for child in collisionmaker.get_children():
			if child is RigidBody2D:
				rb = child
				break
		if rb != null:
			rb.apply_impulse(Vector2.ZERO, Vector2(2000, 0))
			# Force break right away, ignoring velocity threshold:
			var break_manager = get_node("BreakManager")  # Adjust path if needed
			if break_manager:
				break_manager._break_object(rb)
