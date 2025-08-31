# res://src/hazards/hazard_worm.gd
@tool
class_name HazardWorm
extends Node2D

# --- Tuning ---
@export var initial_stack: int = 8              # how many boxes in the worm
@export var box_size: Vector2 = Vector2(40, 40)
@export var pin_break_speed: float = 7000.0     # high = wiggly worms that don't snap easily
@export var hazardous: bool = true              # if true, add CHazard to each segment
@export var hazard_damage: float = 10.0         # passed into CHazard if present
@export var friction: float = 1.2               # material friction
@export var linear_damp: float = 0.25           # keep this low so worms wiggle
@export var angular_damp: float = 0.25
@export var add_center_pin: bool = false        # two pins = best wiggle; add a center pin to stiffen if you ever want

const BOX_MASS := 1.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_worm()

func _build_worm() -> void:
	if initial_stack < 2:
		initial_stack = 2

	# Shared material so segments don't slide too easily
	var mat := PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = 0.0

	var previous: RigidBody2D = null
	for i in range(initial_stack):
		var seg := RigidBody2D.new()
		seg.mass = BOX_MASS
		seg.linear_damp = linear_damp
		seg.angular_damp = angular_damp
		seg.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		seg.physics_material_override = mat

		# collision
		var shape := CollisionShape2D.new()
		shape.name = "shape_hazard" if hazardous else "shape"
		var rect := RectangleShape2D.new()
		rect.size = box_size
		shape.shape = rect
		seg.add_child(shape)

		# visual
		var poly := Polygon2D.new()
		var hs := rect.size / 2.0
		poly.polygon = PackedVector2Array([
			Vector2(-hs.x, -hs.y), Vector2(hs.x, -hs.y),
			Vector2(hs.x, hs.y),   Vector2(-hs.x, hs.y)
		])
		poly.color = Color.GRAY
		seg.add_child(poly)

		# place vertically in local space; the spawner can rotate/position this node
		seg.position = Vector2(0, - (i * (box_size.y + 0.5)))  # tiny overlap for stability
		add_child(seg)

		# CHazard data component if requested
		if hazardous:
			var ch := CHazard.new()
			ch.name = "CHazard"
			ch.damage = hazard_damage
			seg.add_child(ch)

		# link to previous with 2 (optionally 3) pins for hinge-y wiggle
		if previous:
			var mid := (seg.position + previous.position) * 0.5
			var x_off := box_size.x * 0.2

			for off in [-x_off, x_off]:
				var pin := BreakableJoint2D.new()
				pin.position = mid + Vector2(off, 0.0)
				pin.set_meta("a", seg)
				pin.set_meta("b", previous)
				pin.break_threshold = pin_break_speed
				add_child(pin)

			if add_center_pin:
				var center := BreakableJoint2D.new()
				center.position = mid
				center.set_meta("a", seg)
				center.set_meta("b", previous)
				center.break_threshold = pin_break_speed
				add_child(center)

		previous = seg
