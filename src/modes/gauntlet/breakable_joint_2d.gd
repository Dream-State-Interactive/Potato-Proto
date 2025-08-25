# src/modes/gauntlet/breakable_joint_2d.gd
class_name BreakableJoint2D
extends PinJoint2D

@export var break_threshold: float = 700.0

var body_a: PhysicsBody2D
var body_b: PhysicsBody2D

func _ready():
	await get_tree().physics_frame
	
	var node_a_ref = get_node_or_null(node_a)
	var node_b_ref = get_node_or_null(node_b)

	if node_a_ref is PhysicsBody2D and node_b_ref is PhysicsBody2D:
		body_a = node_a_ref
		body_b = node_b_ref
	else:
		printerr("BreakableJoint2D could not find its connected PhysicsBody2D nodes.")
		queue_free()

func _physics_process(_delta):
	if not is_instance_valid(body_a) or not is_instance_valid(body_b):
		# If one of the bodies was destroyed, this joint is no longer needed.
		if is_inside_tree():
			queue_free()
		return

	# 2D physics calculation for velocity at a specific point on a rotating body.
	var world_pos = global_position
	
	var r_a = world_pos - body_a.global_position
	var v_a = body_a.linear_velocity + body_a.angular_velocity * r_a.orthogonal()
	
	var r_b = world_pos - body_b.global_position
	var v_b = body_b.linear_velocity + body_b.angular_velocity * r_b.orthogonal()
	
	if (v_a - v_b).length_squared() > break_threshold * break_threshold:
		print("Joint broke!")
		queue_free()
