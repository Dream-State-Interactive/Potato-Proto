extends Control

func _ready():
	# Set the control's size to a fixed large area (larger than viewport).
	size = Vector2(2048, 2048)
	
	# Position the control so it's centered within the viewport.
	var vp_size = get_viewport().get_visible_rect().size
	position = (vp_size - size) / 2
