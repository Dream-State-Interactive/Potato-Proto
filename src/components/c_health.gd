# =============================================================================
# c_health.gd - A Universal Health and Damage Management Component
# =============================================================================
#
# WHAT IT IS:
# A reusable component that gives any node health points. It handles the logic
# for taking damage, healing, and dying.
#
# ARCHITECTURE:
# - It is completely decoupled. It knows nothing about the Player, peeling, or
#   aging. It only manages numbers and emits signals.
# - The Player script listens for these signals ('damaged', 'health_changed')
#   to trigger its own specific visual effects, like peeling and aging.
#   This is an excellent example of separation of concerns.
#
# =============================================================================
class_name CHealth
extends Node

# --- Signals ---
## Emitted whenever health changes, for any reason (damage or healing).
## Perfect for updating UI health bars.
signal health_changed(current_health, max_health)

## Emitted ONLY when damage is taken. It passes along detailed information
## about the impact, which the Player uses for the peeling effect.
signal damaged(amount, contact_point, contact_normal)

## Emitted once when health reaches zero.
signal died

# --- Properties ---
## The maximum health of this object. Can be set in the Inspector.
@export var max_health: float = 100.0
## The current health of this object.
var current_health: float

# --- Godot Functions ---
func _ready():
	# Initialize current health to the maximum when the object is created.
	# Note: The GameManager overrides this for the Player to apply loaded save data.
	current_health = max_health

# --- Public API ---
## The main function for dealing damage. It's called by the Player script.
func take_damage(amount: float, contact_point: Vector2, contact_normal: Vector2):
	# Don't process damage if already dead.
	if current_health <= 0: return

	# Reduce health, using max() to clamp it at 0 so it can't go negative.
	current_health = max(0, current_health - amount)
	
	print("HealthComponent: Taking damage! Health is now ", current_health)
	
	# Emit signals to notify any listeners (like the Player or UI).
	health_changed.emit(current_health, max_health)
	damaged.emit(amount, contact_point, contact_normal)

	# Check for death.
	if current_health == 0:
		died.emit()

## The main function for healing.
func heal(amount: float):
	# Don't process healing if already at full health.
	if current_health >= max_health:
		return

	# Increase health, using min() to clamp it at the maximum value.
	current_health = min(current_health + amount, max_health)
	
	# Emit the health_changed signal. The Player's _on_health_changed function
	# listens for this and will automatically reverse the aging visual.
	health_changed.emit(current_health, max_health)
	print("HealthComponent: Healed! Health is now ", current_health)
