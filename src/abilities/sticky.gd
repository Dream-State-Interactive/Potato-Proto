# src/abilities/sticky.gd
extends Ability

# A timer to control how long the sticky effect lasts.
var duration_timer: Timer
const DURATION: float = 8.0

func _ready():
	# The time before the ability can be used again (starts after activation).
	cooldown_duration = 10.0
	# We don't call super() here because we are fully overriding the base timer and process logic for this special ability.

	# Set up the main cooldown timer (managed by this script, not the base).
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	add_child(cooldown_timer)

	# Set up the separate timer for the effect's duration.
	duration_timer = Timer.new()
	duration_timer.name = "DurationTimer"
	duration_timer.one_shot = true
	duration_timer.wait_time = DURATION
	add_child(duration_timer)
	
	# Emit the initial state.
	state_updated.emit(State.READY, 0.0)

func _process(_delta: float):
	if not duration_timer.is_stopped():
		# If the duration timer is running, we are in the ACTIVE state.
		var remaining = duration_timer.time_left
		state_updated.emit(State.ACTIVE, remaining / DURATION)
	elif not cooldown_timer.is_stopped():
		# If the cooldown timer is running, we are in the COOLDOWN state.
		var remaining = cooldown_timer.time_left
		state_updated.emit(State.COOLDOWN, remaining / cooldown_duration)
	else:
		# If both are stopped, we are READY.
		state_updated.emit(State.READY, 0.0)

func activate(player_body: RigidBody2D):
	# We can only activate if the main cooldown is finished AND the effect isn't already running.
	if cooldown_timer.is_stopped() and duration_timer.is_stopped():
		print("Activating ability: ", self.name)
		# If successful, we call the ability's specific logic.
		perform_ability(player_body)
		# We DO NOT start the cooldown_timer here.
		return true
	else:
		if not duration_timer.is_stopped():
			print("Ability is already active!")
		else:
			print("Ability on cooldown!")
		return false

# The function signature correctly matches the parent class (Ability).
func perform_ability(player_body: RigidBody2D):
	# Safely cast the generic RigidBody2D to our specific Player class.
	var player = player_body as Player
	if not player:
		return # Exit if the cast fails for any reason.

	# Tell the player to turn on the sticky ability.
	if player.has_method("activate_sticky_ability"):
		player.activate_sticky_ability()
		# When the 8-second duration is over, we'll call the player's deactivate method.
		# We use bind() to pass the player reference to the timeout handler.
		duration_timer.timeout.connect(deactivate_on_timeout.bind(player))
		duration_timer.start()

# This function is called after 8 seconds.
func deactivate_on_timeout(player: Player):
	# Check if the player instance is still valid before calling a method on it.
	if is_instance_valid(player) and player.has_method("deactivate_sticky_ability"):
		player.deactivate_sticky_ability()
	
	# Disconnect the signal to prevent potential issues.
	if duration_timer.timeout.is_connected(deactivate_on_timeout):
		duration_timer.timeout.disconnect(deactivate_on_timeout)
		
	# Start the cooldown AFTER the duration has finished.
	cooldown_timer.start(cooldown_duration)
	print("Sticky ability ended. Cooldown started.")
