extends Sprite2D

func _ready():
	# Scale sprite to fit the viewport on startup.
	update_scale()
	
	# Update scale when the viewport size changes.
	get_viewport().connect("size_changed", Callable(self, "update_scale"))

func update_scale():
	if texture:
		var viewport_size = get_viewport().get_visible_rect().size
		var tex_size = texture.get_size()
		
		# Compute uniform scale to match the viewport width.
		var s = viewport_size.x / tex_size.x
		scale = Vector2(s, s)
