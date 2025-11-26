extends Node2D

@onready var black_rect: ColorRect = $BlackBackground
@onready var particles: GPUParticles2D = $Potato_Wipe
@onready var hold_black_screen_timer: Timer = $HoldBlackScreenTimer

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

	hold_black_screen_timer.start()

func _on_hold_black_screen_timer_timeout() -> void:
	transition_opaque.emit()

func finish_transition() -> void:

	# 4) Start fading back to transparent, stop emitting new particles
	particles.emitting = false

	var tween_out = create_tween()
	tween_out.tween_property(black_rect, "modulate:a", 0.0, fade_out_time)
	await tween_out.finished
	queue_free()
