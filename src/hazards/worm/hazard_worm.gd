# res://src/hazards/hazard_worm.gd
@tool
class_name HazardWorm
extends Node2D

# --- Tuning ---
# This is now just a default/editor preview value.
# The actual value will be set dynamically from ProgressionManager at runtime.
@export var initial_stack: int = 3
@export var box_size: Vector2 = Vector2(22, 42)           # longer segments
@export var pin_break_speed: float = 7000.0
@export var hazardous: bool = true
@export var hazard_damage: float = 10.0
@export var friction: float = 1.2
@export var linear_damp: float = 0.25
@export var angular_damp: float = 0.25
@export var add_center_pin: bool = false
@export var body_color: Color = Color(1.0, 0.65, 0.87)   # earthworm pink default

# --- Sleep/Wake control (distance-based) ---
@export var player_path: NodePath
@export var sleep_distance_px: float = 5000.0
@export var wake_distance_px: float = 10000.0
@export var despawn_distance_px: float = 15000.0

@export_group("Progression Scaling")
@export var unlock_at_hills: int = 3
@export var base_stack_size: int = 6
@export var hills_per_stack_increase: int = 5
@export var max_stack_size: int = 8 

const BOX_MASS := 1.0

var bodies: Array[RigidBody2D] = []
var player: Node2D = null
var is_sleeping: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		for child in get_children():
			if child is RigidBody2D or child is Joint2D:
				child.queue_free()
		build_worm()
		return

	var current_hills: int = ProgressionManager.hills_completed

	if current_hills < unlock_at_hills:
		queue_free()
		return

	# Calculate the number of progression "steps" that have passed.
	var steps: int = int((current_hills - unlock_at_hills) / hills_per_stack_increase)
	
	# Calculate the final stack size based on its own scaling rules.
	var calculated_stack_size = base_stack_size + steps
	
	# Apply the cap and set the final value for building.
	self.initial_stack = min(calculated_stack_size, max_stack_size)

	# 2. Now that properties are correctly set, build the physical worm.
	build_worm()
	collect_bodies()
	resolve_player()


# The rest of your script (physics_process, build_worm, etc.) remains exactly the same.
# It will now use the dynamically set 'initial_stack' value.

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if player == null:
		resolve_player()
		if player == null:
			return
	# ========= Despawn =========
	var dist2 := player.global_position.distance_squared_to(global_position)
	if dist2 > despawn_distance_px * despawn_distance_px:
		queue_free()
		return

	# ========= Sleep / Wake =========
	var dx: float = abs(player.global_position.x - global_position.x)

	if not is_sleeping and dx > sleep_distance_px:
		set_segments_sleeping(true)
	elif is_sleeping and dx < wake_distance_px:
		set_segments_sleeping(false)

func set_segments_sleeping(sleeping: bool) -> void:
	is_sleeping = sleeping
	for b: RigidBody2D in bodies:
		if not is_instance_valid(b):
			continue
		if sleeping:
			b.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			b.linear_velocity = Vector2.ZERO
			b.angular_velocity = 0.0
			b.freeze = true
		else:
			b.freeze = false
			b.sleeping = false

func collect_bodies() -> void:
	bodies.clear()
	for child in get_children():
		if child is RigidBody2D:
			bodies.append(child as RigidBody2D)

func resolve_player() -> void:
	if player_path != NodePath("") and has_node(player_path):
		player = get_node(player_path) as Node2D
		if player:
			return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		player = players[0] as Node2D

func build_worm() -> void:
	if initial_stack < 2:
		initial_stack = 2

	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = friction
	mat.bounce = 0.0

	var previous: RigidBody2D = null
	for i in range(initial_stack):
		var seg: RigidBody2D = RigidBody2D.new()
		seg.mass = BOX_MASS
		seg.linear_damp = linear_damp
		seg.angular_damp = angular_damp
		seg.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
		seg.physics_material_override = mat

		# collision
		var shape: CollisionShape2D = CollisionShape2D.new()
		shape.name = "shape_hazard" if hazardous else "shape"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = box_size
		shape.shape = rect
		seg.add_child(shape)

		# visual (earthworm pink)
		var poly: Polygon2D = Polygon2D.new()
		var hs: Vector2 = rect.size / 2.0
		poly.polygon = PackedVector2Array([
			Vector2(-hs.x, -hs.y), Vector2(hs.x, -hs.y),
			Vector2(hs.x, hs.y),   Vector2(-hs.x, hs.y)
		])
		poly.color = body_color
		seg.add_child(poly)

		seg.position = Vector2(0, - (i * (box_size.y + 0.5)))
		add_child(seg)

		if hazardous:
			var ch: CHazard = CHazard.new()
			ch.name = "CHazard"
			ch.damage = hazard_damage
			seg.add_child(ch)

		if previous:
			var mid: Vector2 = (seg.position + previous.position) * 0.5
			var x_off: float = box_size.x * 0.2

			for off: float in [-x_off, x_off]:
				var pin: BreakableJoint2D = BreakableJoint2D.new()
				pin.position = mid + Vector2(off, 0.0)
				pin.set_meta("a", seg)
				pin.set_meta("b", previous)
				pin.break_threshold = pin_break_speed
				add_child(pin)

			if add_center_pin:
				var center: BreakableJoint2D = BreakableJoint2D.new()
				center.position = mid
				center.set_meta("a", seg)
				center.set_meta("b", previous)
				center.break_threshold = pin_break_speed
				add_child(center)

		previous = seg
