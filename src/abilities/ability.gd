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

enum State {
	READY,
	ACTIVE,
	COOLDOWN
}

# --- Signals ---
## Emitted every frame to update UI elements like cooldown bars.
## 'state' is one of the enum values (READY, ACTIVE, COOLDOWN).
## 'progress' is a value from 0.0 (ready) to 1.0 (on cooldown, just used).
signal state_updated(state, progress)

# --- Configuration ---
## The duration of the cooldown in seconds after the ability is used.
## This can be overridden in the scripts for specific abilities.
@export var cooldown_duration: float = 5.0

# --- Internal State ---
# A reference to the Timer node that will handle the cooldown countdown.
var cooldown_timer: Timer

# --- Godot Functions ---
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
	state_updated.emit(State.READY, 0.0)

func _process(_delta: float):
	if not cooldown_timer.is_stopped():
		var remaining = cooldown_timer.time_left
		state_updated.emit(State.COOLDOWN, remaining / cooldown_duration)
	else:
		state_updated.emit(State.READY, 0.0)

# --- Public API ---
## This is the main function the Player script will call to try and use the ability.
## It returns 'true' on a successful activation and 'false' on failure.
func activate(player_body: RigidBody2D):
	if cooldown_timer.is_stopped():
		print("Activating ability: ", self.name)
		perform_ability(player_body)
		cooldown_timer.start(cooldown_duration)
		return true
	else:
		print("Ability on cooldown!")
		# Optional: Play a "cooldown" or "failure" sound effect here.
		return false

func perform_ability(player_body: RigidBody2D):
	# Base ability does nothing on its own.
	pass
