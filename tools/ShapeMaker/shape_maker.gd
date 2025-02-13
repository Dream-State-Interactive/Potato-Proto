@tool
extends Node2D

enum ShapeType {
	CIRCLE,
	RECTANGLE
}

@export var shape_type: ShapeType = ShapeType.CIRCLE:
	set(value):
		shape_type = value
		_update_visuals()
		_update_collision()

@export var shape_color: Color = Color(1, 0, 0):
	set(value):
		shape_color = value
		queue_redraw()

@export var circle_radius: float = 50.0:
	set(value):
		circle_radius = value
		_update_visuals()
		_update_collision()

@export var rectangle_size: Vector2 = Vector2(100, 50):
	set(value):
		rectangle_size = value
		_update_visuals()
		_update_collision()

@export var create_collision: bool = false:
	set(value):
		create_collision = value
		_update_collision()

@export var enable_physics: bool = false:
	set(value):
		enable_physics = value
		_update_collision()  # Now properly replaces StaticBody2D with RigidBody2D

@export var collision_layer: int = 1
@export var collision_mask: int = 1

func _draw():
	# This function is called every frame (or when queue_redraw() is called) to draw the shape.
	# It checks the shape_type and draws either a circle or a rectangle.
	if shape_type == ShapeType.CIRCLE:
		# Draw a circle centered at (0, 0) with the specified radius and color.
		draw_circle(Vector2.ZERO, circle_radius, shape_color)
	elif shape_type == ShapeType.RECTANGLE:
		# Draw a rectangle centered at (0, 0). The rectangle's top-left corner is calculated
		# by subtracting half of the rectangle's size from the center.  This ensures
		# the rectangle is drawn centered on the origin (0, 0).
		draw_rect(Rect2(-rectangle_size / 2, rectangle_size), shape_color)

func _ready():
	# _ready() is called when the node enters the scene tree.
	# This block ensures that the collision and visuals are updated only when the
	# game is running in the editor.  This is important because the editor
	# automatically instantiates the node to display it in the scene editor.
	if not Engine.is_editor_hint():
		# Exit early if not in the editor.
		return
	_update_visuals()
	_update_collision()

func _update_visuals():
	# This function simply calls queue_redraw() to signal that the node's visuals
	# need to be updated. This is important because changes to properties
	# (shape_color, circle_radius, etc.) do not automatically trigger a redraw.
	queue_redraw()

func _update_collision():
	# This function handles creating or updating the collision object.
	# It first removes any existing collision object and then creates a new one
	# based on the current settings (shape_type, create_collision, enable_physics).

	_remove_existing_collision()  # Remove any old collision shapes before creating new ones.

	if not create_collision:
		# If create_collision is false, no collision object should be created.
		return

	var collision_parent: CollisionObject2D  # Declare a variable to hold either a StaticBody2D or RigidBody2D.

	# If enable_physics is true, create a RigidBody2D; otherwise, create a StaticBody2D.
	# This allows the shape to be either a static object (for collisions but not movement)
	# or a dynamic object that responds to physics (gravity, collisions, etc.).
	if enable_physics:
		collision_parent = RigidBody2D.new() # Create a RigidBody2D if physics are enabled.
		collision_parent.collision_layer = collision_layer # Set the collision layer for the rigid body.
		collision_parent.collision_mask = collision_mask  # Set the collision mask for the rigid body.
		collision_parent.name = "PhysicsBody"             # Give the RigidBody2D a name for easy access and removal.
	else:
		collision_parent = StaticBody2D.new()  # Create a StaticBody2D if physics are disabled.
		collision_parent.name = "CollisionParent"         # Give the StaticBody2D a name for easy access and removal.

	add_child(collision_parent)  # Add the StaticBody2D or RigidBody2D to the scene.
	collision_parent.set_owner(get_tree().edited_scene_root if get_tree() else self) # Set the owner to ensure that it gets automatically saved with the scene.

	var shape_node = CollisionShape2D.new()  # Create a CollisionShape2D node to hold the collision shape.
	var shape: Shape2D # Declare a variable to store the actual shape (CircleShape2D or RectangleShape2D).

	# Determine the correct shape based on the shape_type.
	if shape_type == ShapeType.CIRCLE:
		shape = CircleShape2D.new()
		shape.radius = circle_radius
	elif shape_type == ShapeType.RECTANGLE:
		shape = RectangleShape2D.new()
		shape.size = rectangle_size

	shape_node.shape = shape               # Assign the created shape to the CollisionShape2D.
	shape_node.name = "CollisionShape2D"      # Give the collision shape a name for possible future access.
	collision_parent.add_child(shape_node) # Add the CollisionShape2D as a child of the StaticBody2D or RigidBody2D.
	shape_node.set_owner(get_tree().edited_scene_root if get_tree() else self) # Set the owner for saving.

func _remove_existing_collision():
	# This function removes any existing collision objects (StaticBody2D or RigidBody2D).
	# This is important for preventing multiple collision objects from being created and
	# potentially causing conflicts or unexpected behavior.

	var existing_parent = get_node_or_null("CollisionParent")  # Try to get the existing StaticBody2D.
	if existing_parent:
		existing_parent.queue_free()  # If found, remove it from the scene tree.

	var existing_physics = get_node_or_null("PhysicsBody")  # Try to get the existing RigidBody2D
	if existing_physics:
		existing_physics.queue_free()  # If found, remove it from the scene tree.
