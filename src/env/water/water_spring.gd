# water_spring.gd
extends Node2D

var velocity: float = 0.0

# This signal will tell the main Water node which spring was hit and with what force.
signal splashed(spring_index_name, force)

@onready var area_2d: Area2D = $Area2D

# Called by the main Water manager to run the physics simulation.
func spring_update(stiffness: float, damping: float, target_y: float, delta: float):
	var displacement = position.y - target_y
	var force = -stiffness * displacement - damping * velocity
	velocity += force * delta
	position.y += velocity * delta

# Called by the manager to set its initial state.
func initialize(x_pos: float, new_target_y: float):
	position.x = x_pos
	position.y = new_target_y

# Called by the manager to set the size of our small collision area.
func set_collision_size(width: float, height: float):
	if area_2d.get_child(0) is CollisionShape2D:
		var shape = area_2d.get_child(0).shape as RectangleShape2D
		shape.size = Vector2(width, height)
		area_2d.get_child(0).position.y = height * 0.5

# When a body enters THIS spring's area, we tell the manager.
func _on_area_2d_body_entered(body: Node2D) -> void:
	if Engine.is_editor_hint(): return

	var vel_y: float = 0.0
	if body is CharacterBody2D:
		vel_y = body.velocity.y
	elif body is RigidBody2D:
		vel_y = body.linear_velocity.y
	else:
		return

	# Emit the signal with our own name (which is our index) and the force.
	emit_signal("splashed", name, vel_y * 0.1)
