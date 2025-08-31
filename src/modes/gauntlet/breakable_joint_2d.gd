# src/modes/gauntlet/breakable_joint_2d.gd
class_name BreakableJoint2D
extends PinJoint2D

@export var break_threshold: float = 700.0

var body_a: RigidBody2D
var body_b: RigidBody2D

func _ready():
	await get_tree().physics_frame

	# Typed locals to avoid Variant inference warnings:
	var a_meta: RigidBody2D = null
	var b_meta: RigidBody2D = null
	if has_meta("a"):
		a_meta = (get_meta("a") as RigidBody2D)
	if has_meta("b"):
		b_meta = (get_meta("b") as RigidBody2D)

	# Late-bind NodePaths from meta if provided
	if a_meta and b_meta:
		node_a = get_path_to(a_meta)
		node_b = get_path_to(b_meta)

	var node_a_ref: Node = get_node_or_null(node_a)
	var node_b_ref: Node = get_node_or_null(node_b)

	if node_a_ref is RigidBody2D and node_b_ref is RigidBody2D:
		body_a = node_a_ref as RigidBody2D
		body_b = node_b_ref as RigidBody2D
	else:
		printerr("BreakableJoint2D could not find its connected RigidBody2D nodes.")
		queue_free()

func _physics_process(_delta):
	if not is_instance_valid(body_a) or not is_instance_valid(body_b):
		# If one of the bodies was destroyed, this joint is no longer needed.
		if is_inside_tree():
			queue_free()
		return

	# 2D physics calculation for velocity at a specific point on a rotating body.
	var world_pos: Vector2 = global_position

	var r_a: Vector2 = world_pos - body_a.global_position
	var v_a: Vector2 = body_a.linear_velocity + body_a.angular_velocity * r_a.orthogonal()

	var r_b: Vector2 = world_pos - body_b.global_position
	var v_b: Vector2 = body_b.linear_velocity + body_b.angular_velocity * r_b.orthogonal()

	if (v_a - v_b).length_squared() > break_threshold * break_threshold:
		print("Joint broke!")
		queue_free()

# Make's joints on the left & right between boxes to 'weld' them together
func _make_weld_pair(parent: Node, top: RigidBody2D, bottom: RigidBody2D, width: float) -> void:
	var offsets := [Vector2(-width * 0.2, 0.0), Vector2(width * 0.2, 0.0)]
	for off in offsets:
		var pin := BreakableJoint2D.new()
		pin.position = (top.position + bottom.position) * 0.5 + off
		pin.set_meta("a", top)
		pin.set_meta("b", bottom)
		pin.break_threshold = 700.0
		parent.add_child(pin)
