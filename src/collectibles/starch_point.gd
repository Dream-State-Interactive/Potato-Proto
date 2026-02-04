# src/collectibles/starch_point.gd
@tool
class_name StarchPoint
extends Collectible

@export var starch_value: int = 10
@export var pickup_sound: AudioStream = preload("res://assets/sfx/StarchyCrunch.ogg")
@export var pitch_scale: float = 0.2
@export var volume_db: float = -8.0

func _ready():
	# Standard setup
	body_entered.connect(_on_triggered)
	
	# Connect visibility notifier to toggle physics
	var notifier = $VisibleOnScreenNotifier2D
	if notifier:
		notifier.screen_entered.connect(func(): 
			monitoring = true
			monitorable = true
		)
		notifier.screen_exited.connect(func(): 
			monitoring = false
			monitorable = false
		)
		# Start disabled if spawned off-screen
		if not notifier.is_on_screen():
			monitoring = false
			monitorable = false
	else:
		push_warning("StarchPoint is missing VisibleOnScreenNotifier2D! Performance will suffer.")


func _on_collect(player: Player):
	print("Player collected starch point with ID: %s" % unique_id)
	player.add_starch(starch_value)
	AudioService.play_sfx(pickup_sound, pitch_scale, volume_db, global_position, false, 'StarchyCrunch')
	queue_free()
