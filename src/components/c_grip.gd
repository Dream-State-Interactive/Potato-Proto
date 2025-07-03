# c_grip.gd
# =============================================================================
# GRIP COMPONENT for a RigidBody2D
# =============================================================================
#
# WHAT IT IS:
# This script is a "component" that gives a RigidBody2D the ability to "grip"
# and climb walls and ceilings. It's designed to be a child node of the player
#
# HOW IT WORKS (THE "DELEGATION" PATTERN):
# The parent RigidBody2D will still use its `_integrate_forces` function, but
# it will simply "delegate" the work by calling this component's public function:
# `process_grip_physics()`. This component then does all the heavy lifting and
# directly modifies the physics state.
#
# =============================================================================

# `class_name CGrip` makes "CGrip" a custom type in Godot. This allows us to
# strongly type variables, like `var grip_component: CGrip`, which provides
# better error-checking and code autocompletion.
class_name CGrip
extends Node 

# -----------------------------------------------------------------------------
# EXPORTED PARAMETERS
# -----------------------------------------------------------------------------
@export_group("Tuning", "grip_")

## How well the player can climb steep surfaces. 0.0 means only shallow slopes,
## 1.0 means full 180-degree climbing (including flat ceilings).
@export_range(0.0, 1.0) var grip_strength: float = 1.0

## The player's movement speed (in pixels/sec) when actively climbing a surface.
@export var climb_speed: float = 250.0

## The minimum angle a surface must have for grip to activate.
## This is crucial to prevent the player from getting "stuck" on flat or nearly-flat floors.
@export var min_grip_activation_angle_deg: float = 15.0

## How fast the player SPINS while climbing. This is a visual effect, not a
## physics force, providing direct control over the rotation speed.
@export var climb_rotation_speed: float = 10.0


@export_group("Thresholds", "grip_")
## If the player is spinning faster than this (in radians/sec), the grip will FAIL, and the player will BOUNCE
## off the surface. Essential for abilities like "extreme torque."
@export var grip_break_angular_velocity: float = 20.0

## Similar to the above, but for linear speed. If the player is moving too fast
## (e.g., after a long fall), they will bounce instead of instantly sticking.
@export var grip_break_linear_velocity: float = 800.0


# -----------------------------------------------------------------------------
# PRIVATE VARIABLES (Internal State)
# -----------------------------------------------------------------------------
var _owner_body: RigidBody2D # A reference to our parent RigidBody2D. We need this transform info.


# -----------------------------------------------------------------------------
# GODOT BUILT-IN FUNCTIONS
# -----------------------------------------------------------------------------
func _ready():
	# Get a reference to the node this component is attached to.
	_owner_body = get_parent()
	
	# `assert` is a debugging function. It checks if a condition is true.
	# If not, it stops with an error. This ensures our component is set up correctly
	assert(_owner_body is RigidBody2D, "CGrip component MUST be a child of a RigidBody2D.")


# -----------------------------------------------------------------------------
# PUBLIC API (Functions the Player Script Will Call)
# -----------------------------------------------------------------------------

# The Player's script will call this every physics frame from within its `_integrate_forces`.
# It returns `true` if gripping is active, and `false` otherwise. This lets
# the Player know whether it should apply its own logic (like rolling torque).
func process_grip_physics(state: PhysicsDirectBodyState2D, roll_input: float) -> bool:
	
	# --- CHECK ELIGIBILITY ---
	# STEP 1: Check if the player is too fast. 
	# If so, stop and let the default physics engine handle the player.
	if abs(state.angular_velocity) > grip_break_angular_velocity or \
	   state.linear_velocity.length() > grip_break_linear_velocity:
		return false # Do not grip, let the physics do it's thing.

	# --- CONDITIONS ---
	# STEP 2: Check if the basic conditions for gripping are met.
	# We must be touching something (`get_contact_count() > 0`) and the
	# player must be actively trying to roll (`roll_input != 0`).
	if state.get_contact_count() > 0 and roll_input != 0:
		
		# Find the most relevant surface to grip onto.
		var best_contact_normal = _find_best_grip_normal(state)

		# If we found a valid surface...
		if best_contact_normal != Vector2.ZERO:
			
			# STEP 3: Check the surface's geometry. Is it steep enough to grip,
			# but not too steep for our current `grip_strength`?
			var surface_angle = abs(Vector2.UP.angle_to(best_contact_normal))
			var min_allowed_angle = deg_to_rad(min_grip_activation_angle_deg)
			var max_allowed_angle = lerp(min_allowed_angle, deg_to_rad(180.0), grip_strength)

			if surface_angle >= min_allowed_angle and surface_angle <= max_allowed_angle:
				# SUCCESS: All conditions met! UwU
				# Apply the grip physics and tell the Player that we are a go, copy.
				_apply_grip_velocity(state, roll_input, best_contact_normal)
				return true
	
	# If any check failed, we reach here. We are not gripping.
	return false


# -----------------------------------------------------------------------------
# PRIVATE HELPERS
# -----------------------------------------------------------------------------
# These functions start with an underscore `_` by convention, signaling that
# they are for internal use only and should not be called from other scripts.

# This function does the actual physics manipulation. 
# It's called only when we have confirmed that the player should be gripping.
func _apply_grip_velocity(state: PhysicsDirectBodyState2D, roll_input: float, grip_normal: Vector2):
	# Instead of using `apply_force()` we are going to directly set the body's `linear_velocity`.
	# We specifically tell the physics engine where to move the RigidBody2D

	# --- STEP 1: CALCULATE THE "CLIMB" VELOCITY (Sliding along the surface) ---

	# `grip_normal` is a vector pointing straight OUT of the wall.
	# `.orthogonal()` is a handy function that rotates a vector by 90 degrees.
	# So, if the normal points "out," the orthogonal vector points "along" the wall.
	# This gives us the direction for our slide/climb movement.
	var climb_direction = grip_normal.orthogonal()
	
	# We combine our direction, desired speed, and the player's input.
	var climb_velocity = climb_direction * -roll_input * climb_speed

	# --- STEP 2: CALCULATE THE "STICK" VELOCITY (Pushing into the surface) ---
	
	# A tiny push is enough to stick to a vertical wall, because gravity isn't
	# pulling us away from it. But on a ceiling, gravity will pull us right off.
	# We need a "sticking" force that smoothly gets stronger as the surface
	# becomes more like a ceiling.

	# The weakest possible push, used for vertical walls.
	var min_stick_velocity = -grip_normal * 1.0
	
	# Cancel out gravity on ceilings
	# gravity_vec.project(grip_normal) finds how much of gravity
	# is pulling you directly off the surface:
	#   - walls → almost zero
	#   - ceilings → equals full gravity
	# Multiply by 1.1 to add a 10% safety margin so you stay stuck.
	var gravity_vec = ProjectSettings.get_setting("physics/2d/default_gravity_vector")
	var max_stick_velocity = gravity_vec.project(grip_normal) * 1.1 # Full anti‐gravity push for ceilings (plus 10% margin)

	# SCALAR CONTROL (from 0.0 to 1.0):
	# The `dot` product is a math trick to compare two directions. 
	# "How much does the surface's 'out' direction (`grip_normal`) line up with the world's 'down' direction (`Vector2.DOWN`)?"
	#   - On a ceiling, they line up perfectly -> Result is 1.0
	#   - On a vertical wall, they are 90 degrees apart -> Result is 0.0
	#   - On an overhang, it's something in between, like 0.6
	var ceiling_factor = max(0.0, grip_normal.dot(Vector2.DOWN)) # `max` prevents weirdness on floors.
	
	# WILL IT BLEND:
	# `lerp` (linear interpolation) is controls our scalar.
	# It blends between the min and max stick velocities, using our `ceiling_factor` to decide the final mix.
	var stick_velocity = min_stick_velocity.lerp(max_stick_velocity, ceiling_factor)
	
	# --- STEP 3: APPLY THE FINAL MOVEMENT ---

	# To get our final velocity, we combine our two calculated movements.
	# BUT, there's a catch: after this function runs, Godot's physics engine
	# will *still* apply its normal gravity for this frame.
	
	# This calculates the exact "kick" from gravity that Godot is about to apply.
	var counter_gravity_velocity = -state.total_gravity * state.step
	
	# We add the opposite of gravity's kick to our final velocity. This
	# perfectly cancels out the engine's gravity before it even happens,
	# giving us absolute control over the player's movement.
	state.linear_velocity = climb_velocity + stick_velocity + counter_gravity_velocity
	
	# --- STEP 4: APPLY THE VISUAL ROTATION ---

	# Just like with movement, we specifically adjust the rotation speed.
	# This prevents jittering and stuttering from the physics engine's friction
	state.angular_velocity = roll_input * climb_rotation_speed


# Finds the most logical surface to grip onto from all current contacts.
func _find_best_grip_normal(state: PhysicsDirectBodyState2D) -> Vector2:
	# We need to find the surface that is most "under" the player, even if the player is upside down. 
	# A simple check of world coordinates isn't enough.
	
	var best_normal = Vector2.ZERO
	# The player's local "down" vector changes as they rotate. `transform.y`
	# is the body's local y-axis, which points "down" relative to the sprite.
	var local_down = _owner_body.transform.y
	var max_dot = -INF # Start with the lowest possible value.

	# Loop through every point of contact the physics body is reporting.
	for i in range(state.get_contact_count()):
		var normal = state.get_contact_local_normal(i)
		
		# A dot product tells us how much two vectors point in the same direction.
		# By checking the contact normal against the player's inverted local down
		# vector (`-local_down`), we find the normal that points most "up"
		# relative to the player. This is the surface they are "on".
		var dot = normal.dot(-local_down)
		
		# If this surface is a better match than any we've seen so far, store it.
		if dot > max_dot:
			max_dot = dot
			best_normal = normal
			
	return best_normal
