extends Node2D

@onready var black_rect: ColorRect = $BlackBackground
@onready var particles: GPUParticles2D = $Potato_Wipe

const fade_time = 2.0

signal transition_opaque
signal transition_completed

func _ready() -> void:
	transition_opaque.connect(Callable(SceneLoader, "_on_transition_opaque"))
	start_transition()
	
func start_transition() -> void:
	# Ensure starting state
	black_rect.modulate.a = 0.0
	particles.emitting = true

	# Fade to black while particles are falling
	var tween_in = create_tween()
	tween_in.tween_property(black_rect, "modulate:a", 1.0, fade_time)
	await tween_in.finished
	transition_opaque.emit()
	
func finish_transition() -> void:

	# 4) Start fading back to transparent, stop emitting new particles
	particles.emitting = false

	var tween_out = create_tween()
	tween_out.tween_property(black_rect, "modulate:a", 0.0, fade_time)
	await tween_out.finished

	# 5) Wait for remaining particles to fall off-screen, then clean up
	# Use particles.lifetime (or slightly more) as a rough upper bound.
	var extra_time := particles.lifetime
	await get_tree().create_timer(extra_time).timeout

	transition_completed.emit()
	queue_free()
