# src/modes/gauntlet/obstacle_generator.gd
@tool
extends Node2D

const BOX_MASS := 1

@export var use_weld: bool = true                 # true = 2 pins (rigid), false = 1 pin (hinge)
@export var pin_break_speed: float = 700.0        # units per second at the anchor
@export var box_size: Vector2 = Vector2(40, 40)   # size used for shapes & weld offset

func generate_obstacle(complexity: int) -> Dictionary:
	var obstacle_area := Node2D.new()
	obstacle_area.name = "Obstacle"
	var obstacle_width := 1000.0

	# Create the floor of the obstacle area.
	var base := StaticBody2D.new()
	var base_shape := CollisionShape2D.new()
	var base_rect := RectangleShape2D.new()
	base_rect.size = Vector2(obstacle_width, 20)
	base_shape.shape = base_rect
	base.position = Vector2(obstacle_width / 2.0, 10)
	base.add_child(base_shape)

	var base_visual := Polygon2D.new()
	var half_size_base := base_rect.size / 2.0
	var base_corners := PackedVector2Array([
		Vector2(-half_size_base.x, -half_size_base.y),
		Vector2( half_size_base.x, -half_size_base.y),
		Vector2( half_size_base.x,  half_size_base.y),
		Vector2(-half_size_base.x,  half_size_base.y)
	])
	base_visual.polygon = base_corners
	base_visual.color = Color.GRAY.darkened(0.5)
	base.add_child(base_visual)
	obstacle_area.add_child(base)

	# Create a tower of breakable boxes.
	var previous_box: RigidBody2D = null
	for i in range(complexity):
		var box := RigidBody2D.new()
		box.mass = BOX_MASS

		# Collision
		var box_shape := CollisionShape2D.new()
		var box_rect := RectangleShape2D.new()
		box_rect.size = box_size
		box_shape.shape = box_rect
		box.add_child(box_shape)

		# Visual
		var box_poly := Polygon2D.new()
		var half_size_box := box_rect.size / 2.0
		var box_corners := PackedVector2Array([
			Vector2(-half_size_box.x, -half_size_box.y),
			Vector2( half_size_box.x, -half_size_box.y),
			Vector2( half_size_box.x,  half_size_box.y),
			Vector2(-half_size_box.x,  half_size_box.y)
		])
		box_poly.polygon = box_corners
		box_poly.color = Color.GRAY
		box.add_child(box_poly)

		# Position (stack the boxes flush)
		box.position = Vector2(obstacle_width / 2.0, -20.0 - (i * (box_size.y + 0.5)))
		obstacle_area.add_child(box)

		# Joint(s)
		if previous_box:
			if use_weld:
				# Two pins at slight horizontal offsets to prevent relative rotation (pseudo-weld)
				var mid := (box.position + previous_box.position) * 0.5
				var x_off := box_size.x * 0.2
				for off in [-x_off, x_off]:
					var pin := BreakableJoint2D.new()
					pin.position = mid + Vector2(off, 0.0)
					pin.set_meta("a", box)
					pin.set_meta("b", previous_box)
					pin.break_threshold = pin_break_speed
					obstacle_area.add_child(pin)
			else:
				# Single hinge pin
				var pin := BreakableJoint2D.new()
				pin.position = (box.position + previous_box.position) * 0.5
				pin.set_meta("a", box)
				pin.set_meta("b", previous_box)
				pin.break_threshold = pin_break_speed
				obstacle_area.add_child(pin)

		previous_box = box

	return {
		"node": obstacle_area,
		"width": obstacle_width
	}
