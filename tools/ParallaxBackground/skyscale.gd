extends Sprite2D

func _ready():
	# Scale the sprite to match the viewport's width on startup.
	update_scale()
	
	# Listen for viewport size changes and adjust scale dynamically.
	get_viewport().connect("size_changed", Callable(self, "update_scale"))

func update_scale():
	if texture:
		var viewport_size = get_viewport().get_visible_rect().size
		var tex_size = texture.get_size()
		
		# Compute a uniform scale factor to ensure the sprite spans the screen width.
		var s = (viewport_size.x / tex_size.x) * 1.1  # Increase size by 10%
		scale = Vector2(s, s)
