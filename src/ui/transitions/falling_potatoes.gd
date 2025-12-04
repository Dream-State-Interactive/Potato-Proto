extends Node2D

@onready var black_rect: ColorRect = $BlackBackground
@onready var particles: GPUParticles2D = $Potato_Wipe

const fade_in_time = 1.25
const fade_out_time = 0.85

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
	tween_in.tween_property(black_rect, "modulate:a", 1.0, fade_in_time)
	
	await tween_in.finished
	transition_opaque.emit()

func finish_transition() -> void:
	particles.emitting = false
	var tween_out = create_tween()
	tween_out.tween_property(black_rect, "modulate:a", 0.0, fade_out_time)
	await tween_out.finished
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_completed.emit()
	if particles.speed_scale > 0:
		var remaining_life = particles.lifetime / particles.speed_scale
		await get_tree().create_timer(remaining_life).timeout
	queue_free()
