# src/abilities/extreme_torque.gd
extends Ability

func _ready():
	cooldown_duration = 8.0
	super()

func perform_ability(player_body: RigidBody2D):
	# Apply a massive, one-shot rotational force.
	# We can use the current roll input to decide the direction.
	var roll_input = Input.get_axis("roll_left", "roll_right")
	
	# If the player isn't pressing a direction, give a small boost forward (clockwise).
	if roll_input == 0:
		roll_input = 1.0 
		
	# This torque value should be very large.
	var torque_impulse = 50000.0
	player_body.apply_torque_impulse(roll_input * torque_impulse)
