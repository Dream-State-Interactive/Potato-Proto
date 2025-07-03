# src/abilities/stop_on_a_fry.gd
extends Ability

func _ready():
	# Override the base cooldown duration for this specific ability.
	cooldown_duration = 2.0
	super() # Call the parent's _ready() function to set up the timer.

func perform_ability(player_body: RigidBody2D):
	# The magic: instantly halt all movement and rotation.
	player_body.linear_velocity = Vector2.ZERO
	player_body.angular_velocity = 0.0
	
	# Optional: play a "screech" sound effect here.
