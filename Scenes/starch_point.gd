extends Area2D

@export var pickup_sound: AudioStream  # Export variable to pick the sound
@export var pitch_scale: float = 1.5  # Export pitch scale for easy tweaking in the editor
@export var volume_db: float = -6.0  # Export volume in decibels (default to -6 dB)

func _on_body_entered(body):
	# Check if the body is in the "player" group
	if body.is_in_group("player"):
		# Increment points in the player script
		body.points_available += 1
		body.update_hud()  # Update the HUD to reflect the new points
		
		# Play the pickup sound with the set pitch scale and volume
		if pickup_sound:
			var audio_player = AudioStreamPlayer2D.new()
			audio_player.stream = pickup_sound
			audio_player.pitch_scale = pitch_scale
			audio_player.volume_db = volume_db  # Set the volume in decibels
			audio_player.position = position  # Set the position to the Area2D's position
			get_tree().root.add_child(audio_player)  # Add to scene root instead
			audio_player.play()
			
			# Queue free the audio player after it finishes playing
			audio_player.connect("playback_finished", Callable(audio_player, "queue_free"))
		
		queue_free()  # Remove the Area2D after the player collects it
