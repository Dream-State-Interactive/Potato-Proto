# =============================================================================
# ability.gd - The Base Template for All Player Abilities
# =============================================================================
#
# WHAT IT IS:
# This script is a "base class" that other, specific ability scripts (like
# StopOnAFry.gd) will 'extend'. It provides the core functionality that all
# abilities share: a cooldown system and a standard way to be activated.
# It is designed to be a self-contained component.
#
# ARCHITECTURE:
# - It uses a Timer node, created in code, to manage its cooldown state.
# - It emits a 'cooldown_updated' signal every frame. This allows other parts
#   of the game (like the UI/HUD) to visually represent the cooldown progress
#   without needing to know anything about the ability's specific logic. This
#   is a great example of keeping systems decoupled.
#
# =============================================================================
class_name Ability
extends Node

# --- Signals ---
## Emitted every frame to update UI elements like cooldown bars.
## 'progress' is a value from 0.0 (ready) to 1.0 (on cooldown, just used).
signal cooldown_updated(progress)

# --- Configuration ---
## The duration of the cooldown in seconds after the ability is used.
## This can be overridden in the scripts for specific abilities.
@export var cooldown_duration: float = 5.0

# --- Internal State ---
# A reference to the Timer node that will handle the cooldown countdown.
var cooldown_timer: Timer

# --- Godot Functions ---

# _ready() runs once when the node is added to the scene tree and ready.
# It's used for one-time setup.
func _ready():
	# We create the Timer node in code rather than requiring it to be added
	# in the editor. This makes the ability component easier to set up.
	cooldown_timer = Timer.new()
	# 'one_shot = true' means the timer will run once for the cooldown
	# duration and then stop, instead of repeating.
	cooldown_timer.one_shot = true
	# The timer must be a child of a node in the scene tree to function.
	add_child(cooldown_timer)
	
	# Emit the initial state (0.0 for 0% cooldown) to ensure the UI
	# correctly displays the ability as "ready" at the start.
	cooldown_updated.emit(0.0)

# _process(delta) runs on every visual frame. It's ideal for continuous
# updates, like animating a cooldown bar.
func _process(_delta: float):
	# We constantly check the state of our cooldown timer.
	if not cooldown_timer.is_stopped():
		# If the timer is running, we calculate the remaining time.
		var remaining = cooldown_timer.time_left
		# We emit the progress as a percentage (a value from 0.0 to 1.0),
		# which is easy for UI elements like ProgressBars to use.
		cooldown_updated.emit(remaining / cooldown_duration)
	else:
		# If the timer is stopped, the ability is ready. We emit 0.0 to ensure
		# the UI cooldown bar is empty. This 'else' block handles the case
		# where the UI might be slightly out of sync.
		cooldown_updated.emit(0.0)

# --- Public API ---

## This is the main function the Player script will call to try and use the ability.
## It returns 'true' on a successful activation and 'false' on failure.
func activate(player_body: RigidBody2D):
	# The core logic: we only allow activation if the cooldown timer is finished.
	if cooldown_timer.is_stopped():
		print("Activating ability: ", self.name)
		# If successful, we call the ability's specific logic...
		perform_ability(player_body)
		# ...and then immediately start the cooldown timer.
		cooldown_timer.start(cooldown_duration)
		return true # Let the caller know the ability was successfully used.
	else:
		print("Ability on cooldown!")
		# Optional: Play a "cooldown" or "failure" sound effect here.
		return false # Let the caller know the ability could not be used.

# This is a "virtual" function. It is meant to be empty in the base class.
# Specific ability scripts that 'extend' this one will provide their own
# implementation of this function, defining what the ability actually does.
func perform_ability(player_body: RigidBody2D):
	# Base ability does nothing on its own.
	pass
