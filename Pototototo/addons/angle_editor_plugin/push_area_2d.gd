# Filename: push_area_2d.gd

## A highly configurable trigger area that applies a directional force to physics bodies.
## It is designed to be a completely self-contained scene, providing its own
## visual gizmos in the editor for intuitive level design.
## It integrates with the Angle Editor plugin to provide a custom Inspector dial.
@tool
extends Area2D

## The base direction of the push, in degrees. 0 is right, 90 is down.
## The "_angle" suffix is a special convention that our addon uses to
## automatically replace the default number input with our custom dial UI.
@export var push_direction_angle: float = 0.0

## The base strength of the push force at its origin before any falloff is applied.
@export var push_force: float = 100.0

## If true, the push fires only once as a single "kick" (impulse) per body.
## If false, it applies a continuous force like a fan or conveyor belt.
@export var one_shot: bool = false

# --- Visual Handle and Falloff System ---

## A NodePath that points to the child Node2D used as a visual, draggable handle.
## This must be assigned in the Inspector by dragging the child node into this slot.
@export var origin_handle: NodePath

## The local offset from this node's origin where the push force is strongest.
## This value is controlled by dragging the 'origin_handle' in the 2D viewport.
@export var push_origin_offset: Vector2 = Vector2.ZERO:
	# This 'setter' function runs whenever the 'push_origin_offset' value changes.
	set(value):
		push_origin_offset = value
		
		# TWO-WAY BINDING (Part 1): If this value is changed in the Inspector,
		# update the visual handle's position to match.
		if Engine.is_editor_hint() and has_node(origin_handle):
			var handle_node = get_node(origin_handle)
			# Check to prevent an infinite loop of updates.
			if handle_node.position != value:
				handle_node.position = value
		
		# CRITICAL: Tell the editor that a property has changed. This forces
		# the Inspector to refresh and display the new value.
		if Engine.is_editor_hint():
			notify_property_list_changed()

## Controls how quickly the force diminishes with distance from the origin.
## - 0.0: No falloff. The force is constant everywhere in the area.
## - 1.0: The force fades to zero over a distance of 1000 pixels.
## - Higher values make the falloff happen over a shorter distance.
@export_range(0.0, 10.0, 0.1) var push_falloff: float = 0.0


# --- State tracking variables used at runtime ---
var _pushed_bodies: Array = [] # For one-shot mode, to track which bodies have been pushed.
var _is_disabled: bool = false   # For one-shot mode, to disable the trigger after use.


# _process runs every frame, including in the editor thanks to @tool.
func _process(_delta: float) -> void:
	# This logic should only ever run inside the Godot editor.
	if Engine.is_editor_hint():
		# TWO-WAY BINDING (Part 2): Check if the user has dragged the handle.
		if has_node(origin_handle):
			var handle_node = get_node(origin_handle)
			# If the handle's position doesn't match our stored value, it has been moved.
			if handle_node.position != push_origin_offset:
				# Update our property. This will call the 'setter' function above,
				# which completes the two-way binding and updates the Inspector.
				self.push_origin_offset = handle_node.position
		
		# Continuously request a redraw to keep the gizmos perfectly synced.
		queue_redraw()


# This function draws our custom visuals (gizmos) inside the editor. 
# OBSOLETE IF YOU HAVE AN AngleGizmo2D Node2D with the "angle_gizmo_2d.gd" script attached
# ------------- CURRENTLY COMMENTED OUT BECAUSE IT'S OBSOLETE, BUT STILL HANDLY AS A REFERENCE -------------
#func _draw() -> void:
	#if not Engine.is_editor_hint(): return
		#
	## 1. Draw the Directional Arrow at the node's origin.
	#var direction = Vector2.from_angle(deg_to_rad(push_direction_angle))
	#draw_line(Vector2.ZERO, direction * 30, Color.RED, 2.0, true)
	#draw_line(direction * 30, direction * 20 + direction.orthogonal() * 5, Color.RED, 2.0, true)
	#draw_line(direction * 30, direction * 20 - direction.orthogonal() * 5, Color.RED, 2.0, true)
	#
	## 2. Draw the visual representation of the draggable Origin Handle.
	#draw_circle(push_origin_offset, 6.0, Color.CYAN)
	#draw_circle(push_origin_offset, 4.0, Color.WHITE)


# _physics_process runs every physics frame during the game.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return # Don't run game physics in the editor.
	
	if one_shot and _is_disabled: return
	
	# If this is a continuous push, we apply force every frame.
	if not one_shot:
		for body in get_overlapping_bodies():
			if body is RigidBody2D:
				_apply_push(body)


# This signal handler is called when a body first enters the Area2D.
func _on_body_entered(body: Node2D) -> void:
	if one_shot and _is_disabled: return
	
	# If this is a one-shot push, we only apply force on entry.
	if one_shot:
		if body in _pushed_bodies: return
		
		if body is RigidBody2D:
			_apply_push(body)
			_pushed_bodies.append(body)
			_is_disabled = true


# This centralized function calculates and applies the final push force.
func _apply_push(body: RigidBody2D) -> void:
	var direction_vector = Vector2.from_angle(deg_to_rad(push_direction_angle))
	var final_push_force = push_force
	
	# --- Falloff Calculation Logic ---
	if push_falloff > 0.001: # Check if falloff is enabled.
		# Get the distance from the push origin to the body's center.
		# We must convert the body's global position to our local coordinate space.
		var distance = push_origin_offset.distance_to(to_local(body.global_position))
		# A higher falloff value results in a shorter max_distance.
		var max_distance = 1000.0 / push_falloff
		# This calculates a multiplier from 1.0 (at the origin) to 0.0 (at max_distance).
		var falloff_multiplier = clampf(1.0 - (distance / max_distance), 0.0, 1.0)
		final_push_force *= falloff_multiplier
	
	if final_push_force <= 0.001: return # Don't apply negligible forces.
	
	# Apply the push differently based on the trigger's mode.
	if one_shot:
		# An impulse is a single, instant "kick".
		body.apply_central_impulse(direction_vector * final_push_force)
	else:
		# A force is continuous, like wind. We scale by mass for a consistent feel.
		body.apply_central_force(direction_vector * final_push_force * body.mass)
