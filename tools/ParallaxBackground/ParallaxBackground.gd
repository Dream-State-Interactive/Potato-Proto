extends ParallaxBackground

@export var zoom_dampening: float = 0.02  # Even smaller effect for near-invisible scaling
var camera_node: Camera2D

func _ready():
	scroll_ignore_camera_zoom = true  # Ensures built-in zoom doesn't interfere
	camera_node = get_viewport().get_camera_2d()

func _process(_delta):
	if camera_node:
		# Compute an almost imperceptible scale effect
		var effective_zoom = Vector2.ONE + (camera_node.zoom - Vector2.ONE) * zoom_dampening
		
		# Add subtle scaling ONLY to parallax layers
		for childLayer in get_children():
			if childLayer is ParallaxLayer:
				childLayer.scale = childLayer.scale.lerp(effective_zoom, 0.05)  # Super smooth transition
