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
@export var max_health: float = 100.0:
	set(value):
		max_health = value
		# When max_health changes, re-validate current_health
		if self.is_node_ready(): # Don't run this before _ready()
			self.current_health = _current_health # Re-trigger the setter for clamping

## internal reference for current health
var _current_health: float
## The current health of this object | Setter triggers anytime 'health_component.current_health = X' is performed
var current_health: float:
	get:
		return _current_health
	set(value):
		# 1. Clamp the new value to be between 0 and max_health.
		var new_health = clamp(value, 0, max_health)
		
		# 2. Only proceed if the value has actually changed.
		if new_health == _current_health:
			return
			
		# 3. Update the internal variable.
		_current_health = new_health
		
		# 4. ALWAYS emit the signal when the value changes.
		health_changed.emit(_current_health, max_health)
		print("CHealth setter: Health is now %f / %f" % [_current_health, max_health])

# --- Godot Functions ---
func _ready():
	# Set the property and run setter logic.
	self.current_health = max_health

# --- Public API ---
## The main function for dealing damage. It's called by the Player script.
func take_damage(amount: float, contact_point: Vector2, contact_normal: Vector2):
	# Don't process damage if already dead.
	if _current_health <= 0: 
		return

	# Assign to the current_health, not the internal variable _current_health.
	self.current_health -= amount
	
	print("HealthComponent: Taking damage! Health is now ", current_health)
	
	# Emit signals to notify any listeners (like the Player or UI).
	damaged.emit(amount, contact_point, contact_normal)

	# Check for death.
	if current_health == 0:
		died.emit()

## The main function for healing.
func heal(amount: float):
	# Don't process healing if already at full health.
	if _current_health >= max_health:
		return

	self.current_health += amount
	print("HealthComponent: Healed! Health is now ", current_health)
