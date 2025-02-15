extends ParallaxLayer

@export var scroll_speed: float = 0.5  # Adjustable in Inspector
@export var scroll_direction: Vector2 = Vector2(1, 0) # Default scroll horizontally

var offset = Vector2(0,0)

func _process(delta):
	offset += scroll_direction * scroll_speed * delta
	# Get the Control node as the first child
	var control_node: Control = get_child(0) as Control

	# Safely check if we got a control node
	if control_node:
		# Get the TextureRect as a child of the control node
		var texture_rect: TextureRect = control_node.get_child(0) as TextureRect

		#  Safely check that we got a texture rect
		if texture_rect:
			texture_rect.position = offset # <--- CHANGED TO .position
		else:
			printerr("Error: Control node does not have a TextureRect child!")
	else:
		printerr("Error: Child of ParallaxLayer is not a Control node!")
