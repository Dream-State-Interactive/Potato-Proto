extends Control

@onready var title: TextureRect = $Title
@export var pulse_duration: float = 2.0

# Stores the initial scale of the title set in the scene (0.3, 0.3).
var base_title_scale: Vector2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize the title scale and center its pivot.
	base_title_scale = title.scale
	title.pivot_offset = title.size * 0.5
	
	animate_title()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Recursively animate the title's scale to create a pulsing effect.
func animate_title() -> void:
	# Reset the title's scale to its base value.
	title.scale = base_title_scale
	var tween = title.create_tween()
	
	# Animate scaling up to 1.2× the base scale.
	tween.tween_property(title, "scale", base_title_scale * 1.2, pulse_duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# Animate scaling back down to the base scale.
	tween.tween_property(title, "scale", base_title_scale, pulse_duration) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)
	
	# When the tween completes, call animate_title() again to loop the animation.
	tween.tween_callback(Callable(self, "animate_title"))
