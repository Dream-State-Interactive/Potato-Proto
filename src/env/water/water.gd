@tool
# water.gd — The main controller for the 2D water component.
#
# OVERVIEW:
## This script manages a collection of "WaterSpring" nodes to simulate a dynamic water surface.
# It handles:
#   - Procedurally generating the spring nodes at runtime.
#   - Displaying a lightweight preview in the Godot editor.
#   - Running the physics simulation for waves and propagation.
#   - Applying global physics effects like buoyancy and drag via a main Area2D.
#   - Rendering the final water mesh with a Polygon2D.
#   - Two-way editor integration for resizing the water body.
extends Node2D

# --- EXPORTED VARIABLES (Configurable in the Inspector) ---

@export_group("Visuals")
## The visual color of the water. The alpha channel (A) controls transparency.
@export var water_color: Color = Color("4d72d4b0"):
	set(value):
		water_color = value
		if polygon_2d:
			polygon_2d.color = water_color

## Toggles the visibility of the line on the water's surface.
@export var show_top_line: bool = true:
	set(value):
		show_top_line = value
		if line_2d:
			line_2d.visible = show_top_line

## The color of the line on top of the water.
@export var water_top_color: Color = Color("e0f0ff"):
	set(value):
		water_top_color = value
		if line_2d:
			line_2d.default_color = water_top_color

## The width (thickness) of the line on top of the water.
@export var water_top_width: float = 3.0:
	set(value):
		water_top_width = value
		if line_2d:
			line_2d.width = water_top_width


@export_group("Dimensions")
## The total width of the water body in pixels.
@export var width: float = 1024.0:
	set(value):
		if is_equal_approx(width, value): return
		width = value
		_editor_recalculate()

## The depth of the water body, measured from the surface (y=0) to the bottom.
@export var height: float = 500.0:
	set(value):
		if is_equal_approx(height, value): return
		height = value
		_editor_recalculate()

## The number of springs used to simulate the surface. More points are smoother but cost more performance.
@export var surface_point_count: int = 100:
	set(value):
		if surface_point_count == value: return
		surface_point_count = value
		_editor_recalculate()

@export_group("Physics")

## How strongly the water springs back to its resting position. Higher values mean stiffer, faster waves.
@export var stiffness: float = 90.0
## How much the waves resist motion, causing them to fade over time. Prevents infinite oscillation.
@export var damping: float = 5.0
## How much wave energy is transferred to neighbors each frame. Higher values create wider, faster-spreading waves.
@export var wave_spread: float = 0.25
## How many times wave spreading is calculated per physics frame. Higher values are more stable and smoother.
@export var wave_propagation_iterations: int = 8
## How powerful the initial splash is when an object enters the water. Higher values create bigger waves.
@export var splash_force_multiplier: float = 0.1
## Scales gravity for objects in the water. 0.5 = half gravity (standard buoyancy).
@export var buoyancy_gravity_scale: float = 0.5:
	set(value):
		buoyancy_gravity_scale = value
		if is_node_ready(): 
			_update_area_physics()
## The linear drag applied to objects in the water. A higher value makes the water feel 'thicker'.
@export var water_linear_damp: float = 1.0:
	set(value):
		water_linear_damp = value
		if is_node_ready(): 
			_update_area_physics()
## The rotational drag applied to objects. A higher value makes them stop spinning quickly.
@export var water_angular_damp: float = 1.0:
	set(value):
		water_angular_damp = value
		if is_node_ready(): 
			_update_area_physics()

# --- CONSTANTS & NODE REFERENCES ---

# Preload the WaterSpring scene. This is more efficient than loading it with a string path.
const WaterSpringScene: PackedScene = preload("res://src/env/water/water_spring.tscn")

# Direct references to our child nodes for quick access.
@onready var polygon_2d: Polygon2D = $Polygon2D
@onready var path_2d: Path2D = $Path2D
@onready var area_2d: Area2D = $Area2D
@onready var collision_shape_2d: CollisionShape2D = $Area2D/CollisionShape2D
@onready var line_2d: Line2D = $Line2D # Reference to the Line2D for the top border.

# This array will hold the instantiated WaterSpring NODES at runtime.
var springs: Array = []
# A guard flag to prevent infinite loops when updating properties between the script and the editor.
var _is_updating_from_script: bool = false

# --- GODOT LIFECYCLE & MAIN LOOPS ---

func _ready() -> void:
	# This function runs once, both in the editor and at runtime.
	# We use it to set up the correct processing mode.
	
	# Prepare the Path2D's curve resource to ensure it's unique to this instance.
	if path_2d.curve == null:
		path_2d.curve = Curve2D.new()
	else:
		path_2d.curve = path_2d.curve.duplicate()

	# The logic is split: editor uses _process, runtime uses _physics_process.
	if Engine.is_editor_hint():
		# In the editor, we connect to the shape_changed signal for efficient, event-driven updates.
		if not collision_shape_2d.shape_changed.is_connected(_on_shape_changed):
			collision_shape_2d.shape_changed.connect(_on_shape_changed)
		_recalculate_geometry()
	else:
		# At runtime, we enable the physics loop and connect the Area2D signal for splashes.
		set_physics_process(true)
		area_2d.body_entered.connect(make_splash_from_body)
		_recalculate_geometry()

func _physics_process(delta: float) -> void:
	# This is the main runtime loop, running at a fixed physics rate.
	
	# 1. Update the state of each individual spring based on physics laws.
	for spring in springs:
		spring.spring_update(stiffness, damping, 0.0, delta)
	
	# 2. Propagate the wave energy between neighboring springs.
	_propagate_waves()
	
	# 3. Redraw the water mesh based on the new spring positions.
	_update_visuals()

# --- EDITOR TOOLING FUNCTIONS ---

func _on_shape_changed() -> void:
	# This function is triggered by a signal ONLY when the CollisionShape2D is resized in the editor viewport.
	# This is more efficient than polling every frame in _process.
	
	# If the script is already changing the shape, ignore this signal to prevent a loop.
	if _is_updating_from_script:
		return
	
	var new_size: Vector2 = collision_shape_2d.shape.size
	
	# We use UndoRedo to make this change "official" to the editor.
	# This makes the action undoable (Ctrl+Z) and marks the scene as needing to be saved.
	var undo_redo := UndoRedo.new()
	undo_redo.create_action("Resize Water via Handles")
	# Register the "do" and "undo" actions. We use "set" to ensure the property setters are called.
	undo_redo.add_do_method(Callable(self, "set").bind("width", new_size.x))
	undo_redo.add_do_method(Callable(self, "set").bind("height", new_size.y))
	undo_redo.add_undo_method(Callable(self, "set").bind("width", width))
	undo_redo.add_undo_method(Callable(self, "set").bind("height", height))
	undo_redo.commit_action()

func _editor_recalculate() -> void:
	# This is a helper called by the setters of width, height, and surface_point_count.
	# It ensures that when you type a value in the Inspector, the geometry is rebuilt.
	if Engine.is_editor_hint():
		# call_deferred is crucial for safety. It waits until the end of the frame to modify nodes,
		# preventing instability within the editor.
		call_deferred("_recalculate_geometry")

# --- CORE LOGIC & GEOMETRY ---

func _recalculate_geometry() -> void:
	# This is the master function for building or rebuilding the water body.
	
	# First, clear out any old spring nodes to prevent duplicates.
	for child in get_children():
		if child.is_in_group("water_springs"):
			child.queue_free()
	springs.clear()

	if Engine.is_editor_hint():
		# In the editor, we only draw a simple, lightweight preview.
		# This keeps the editor fast and avoids running complex physics.
		polygon_2d.polygon = PackedVector2Array([Vector2(0,0), Vector2(width,0), Vector2(width,height), Vector2(0,height)])
		polygon_2d.color = water_color
		path_2d.curve.clear_points()
		path_2d.curve.add_point(Vector2(0,0))
		path_2d.curve.add_point(Vector2(width,0))
		
		# Update the Line2D for the editor preview, respecting the toggle.
		if line_2d:
			line_2d.visible = show_top_line
			if show_top_line:
				line_2d.points = path_2d.curve.get_baked_points()
				line_2d.width = water_top_width
				line_2d.default_color = water_top_color
		
		_update_collision_shape()
		return

	# --- Runtime Initialization ---
	# This code only runs when the game starts.
	if surface_point_count < 2: return
	var spacing: float = width / float(surface_point_count - 1)
	
	# Instantiate and configure a line of WaterSpring nodes.
	for i in range(surface_point_count):
		var spring = WaterSpringScene.instantiate()
		spring.name = str(i) # The name acts as its index.
		spring.add_to_group("water_springs") # Add to group for easy cleanup.
		add_child(spring)
		
		# Set the owner. This is CRITICAL for the editor to save instanced scenes correctly.
		if Engine.is_editor_hint():
			spring.owner = get_tree().edited_scene_root
		
		# Initialize the spring with its position and connect its signal.
		spring.initialize(i * spacing, 0)
		spring.set_collision_size(spacing, height * 2) # Give each spring's detector some depth.
		spring.splashed.connect(on_spring_splashed)
		springs.append(spring)

	# Set initial Line2D properties at runtime, respecting the toggle.
	if line_2d:
		line_2d.visible = show_top_line
		if show_top_line:
			line_2d.width = water_top_width
			line_2d.default_color = water_top_color

	_update_collision_shape()
	_update_visuals()
	_update_area_physics()

func _propagate_waves() -> void:
	# This loop spreads the velocity between neighboring springs to create a wave effect.
	# It runs multiple times per frame for a smoother, more stable result.
	for _iteration in range(wave_propagation_iterations):
		for j in range(springs.size()):
			# Propagate to the left neighbor.
			if j > 0:
				var diff = springs[j].position.y - springs[j-1].position.y
				var force = wave_spread * diff
				springs[j-1].velocity += force
				springs[j].velocity -= force
			# Propagate to the right neighbor.
			if j < springs.size() - 1:
				var diff2 = springs[j].position.y - springs[j+1].position.y
				var force2 = wave_spread * diff2
				springs[j+1].velocity += force2
				springs[j].velocity -= force2

func _update_visuals() -> void:
	# This function redraws the Polygon2D mesh every frame based on the springs' current positions.
	if springs.is_empty(): return
	
	var polygon_pts := PackedVector2Array()
	polygon_pts.resize(springs.size() + 2)
	
	var surface_pts := PackedVector2Array()
	surface_pts.resize(springs.size())
	
	# 1. Get the position of every spring on the surface.
	for i in range(springs.size()):
		var spring_pos = springs[i].position
		polygon_pts[i] = spring_pos
		surface_pts[i] = spring_pos
		
	# 2. Add two bottom corners to create a closed shape for the polygon.
	polygon_pts[springs.size()] = Vector2(springs[-1].position.x, height)
	polygon_pts[springs.size() + 1] = Vector2(springs[0].position.x, height)
	
	# 3. Assign the points and color to the Polygon2D.
	polygon_2d.polygon = polygon_pts
	polygon_2d.color = water_color
	
	# 4. Update the Line2D to draw the surface border, if enabled.
	if show_top_line and line_2d:
		line_2d.points = surface_pts
	
	# 5. Also update the Path2D for debugging purposes (visible in editor).
	path_2d.curve.clear_points()
	for pt in surface_pts:
		path_2d.curve.add_point(pt)


func _update_collision_shape() -> void:
	# This function syncs the main buoyancy Area2D's shape to the Inspector properties.
	# It's guarded to prevent feedback loops with the _on_shape_changed signal.
	_is_updating_from_script = true
	collision_shape_2d.shape.size = Vector2(width, height)
	collision_shape_2d.position = Vector2(width * 0.5, height * 0.5)
	_is_updating_from_script = false

# --- SIGNAL HANDLERS & INTERACTION ---

# This function is the receiver for the `splashed` signal from any WaterSpring child.
func on_spring_splashed(index_name: String, force: float) -> void:
	var idx: int = int(index_name)
	if idx >= 0 and idx < springs.size():
		springs[idx].velocity += force

# This function is connected to the main Area2D's `body_entered` signal.
func make_splash_from_body(body: Node2D) -> void:
	# Converts the velocity of an entering body into an initial splash force.
	var vy: float = 0.0
	if body is CharacterBody2D:
		vy = body.velocity.y
	elif body is RigidBody2D:
		vy = body.linear_velocity.y
	
	# Call the splash handler with the calculated index and force.
	on_spring_splashed(get_spring_index_at_pos(body.global_position), vy * splash_force_multiplier)

func get_spring_index_at_pos(global_pos: Vector2) -> String:
	# Helper function to find which spring is closest to a global position.
	var local_pos = to_local(global_pos)
	if local_pos.x < 0.0 or local_pos.x > width:
		return "-1"
	var idx_f = local_pos.x / (width / float(surface_point_count - 1))
	return str(int(round(idx_f)))

func _update_area_physics() -> void:
	# Configures the main Area2D to apply buoyancy and drag.
	# This is the most stable way to create water physics.
	var dir: Vector2 = ProjectSettings.get_setting("physics/2d/default_gravity_vector")
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	
	# We COMBINE our physics settings with the world's default settings.
	area_2d.gravity_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area_2d.gravity_point = false
	area_2d.gravity_direction = -dir  # Invert world gravity to create an upward force.
	area_2d.gravity = g * buoyancy_gravity_scale # Apply our multiplier to the world gravity.
	
	area_2d.linear_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area_2d.linear_damp = water_linear_damp
	
	area_2d.angular_damp_space_override = Area2D.SPACE_OVERRIDE_COMBINE
	area_2d.angular_damp = water_angular_damp
