extends TextureRect

@export var auto_scroll_speed: float = 0.1  # Controls horizontal UV scroll speed.
var time: float = 0.0

func _process(delta):
	# Accumulate elapsed time to drive UV scrolling.
	time += auto_scroll_speed * delta
	
	# Keep UV offset within a 0-1 range to prevent precision errors.
	var new_uv_offset = time - floor(time)
	
	# Apply the updated UV offset to the shader if a ShaderMaterial is assigned.
	if material and material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("uv_offset_x", new_uv_offset)
