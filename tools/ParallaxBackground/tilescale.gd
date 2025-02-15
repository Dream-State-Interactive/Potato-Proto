extends TextureRect

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# No need to force size here; it will inherit from the parent.
	print("CloudsTextureRect size: ", size)
