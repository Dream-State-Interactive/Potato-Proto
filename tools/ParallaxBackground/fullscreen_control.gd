extends Control

func _ready():
	# Center the control within the viewport.
	center_in_viewport()

func center_in_viewport():
	var viewport_size = get_viewport().get_visible_rect().size
	position = viewport_size / 2
