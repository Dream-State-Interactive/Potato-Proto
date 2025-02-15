extends Area2D

@export var underwater_gravity_scale: float = 0.3   # Gravity scale to use when bodies are underwater.
@export var underwater_linear_damp: float = 5.0       # Linear damping to use when bodies are underwater.

# Store original physics properties for bodies so they can be restored on exit.
var original_properties = {}

func _ready():
	# Connect signals for when bodies enter or exit this water volume.
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	# Determine the target node that should receive the water state.
	var target = body
	# If the body doesn't have set_in_water(), check its parent.
	if not body.has_method("set_in_water") and body.get_parent() and body.get_parent().has_method("set_in_water"):
		target = body.get_parent()
	# Notify the target that it is now underwater.
	if target.has_method("set_in_water"):
		target.set_in_water(true)
		
	# For RigidBody2D, store original physics properties and apply underwater settings.
	if body is RigidBody2D:
		original_properties[body] = {
			"gravity_scale": body.gravity_scale,
			"linear_damp": body.linear_damp
		}
		body.gravity_scale = underwater_gravity_scale
		body.linear_damp = underwater_linear_damp

func _on_body_exited(body):
	# Determine the target node that should have water state cleared.
	var target = body
	# If the body doesn't have set_in_water(), check its parent.
	if not body.has_method("set_in_water") and body.get_parent() and body.get_parent().has_method("set_in_water"):
		target = body.get_parent()
	# Notify the target that it is no longer underwater.
	if target.has_method("set_in_water"):
		target.set_in_water(false)
		
	# For RigidBody2D, restore original physics properties.
	if body is RigidBody2D and original_properties.has(body):
		var props = original_properties[body]
		body.gravity_scale = props.gravity_scale
		body.linear_damp = props.linear_damp
		original_properties.erase(body)
