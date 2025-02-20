extends Area2D

@export var pickup_sound: AudioStream  
@export var pitch_scale: float = 1.5  
@export var volume_db: float = -6.0  
@export var scale_min: float = 0.9  # Minimum scale for pulsing effect
@export var scale_max: float = 1.1  # Maximum scale for pulsing effect
@export var pulse_speed: float = 2.0  # Speed of pulsing
@export var scale_amount: float = 0.1  # Amount of scaling for the pulse effect


func _process(delta):
	# Calculate the new scale using a sine wave for a breathing effect
	var scale_factor = 1.0 + sin(Time.get_ticks_msec() * 0.001 * pulse_speed) * scale_amount
	scale = Vector2(scale_factor, scale_factor)


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
