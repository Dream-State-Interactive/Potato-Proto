extends Area2D

@export var underwater_gravity_scale: float = 0.3
@export var underwater_linear_damp: float = 5.0

# Store original properties for bodies so they can be restored
var original_properties = {}

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	# If the body has a method to set its water state, call it
	if body.has_method("set_in_water"):
		body.set_in_water(true)
		
	# If it's a RigidBody2D, modify its physics properties to simulate water
	if body is RigidBody2D:
		original_properties[body] = {
			"gravity_scale": body.gravity_scale,
			"linear_damp": body.linear_damp
		}
		body.gravity_scale = underwater_gravity_scale
		body.linear_damp = underwater_linear_damp

func _on_body_exited(body):
	if body.has_method("set_in_water"):
		body.set_in_water(false)
		
	if body is RigidBody2D and original_properties.has(body):
		var props = original_properties[body]
		body.gravity_scale = props.gravity_scale
		body.linear_damp = props.linear_damp
		original_properties.erase(body)
