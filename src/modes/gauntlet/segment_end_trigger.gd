# src/modes/gauntlet/segment_end_trigger.gd
extends Area2D

signal player_finished_segment

var _is_triggered = false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player") and not _is_triggered:
		_is_triggered = true
		print("Player reached the end of a segment.")
		emit_signal("player_finished_segment")
		# Disable the shape to prevent it from firing again.
		$CollisionShape2D.set_deferred("disabled", true)
