@tool
extends Node2D

enum ShapeType {
	CIRCLE,
	RECTANGLE
}

# Exported properties with the old colon setter syntax (Godot 4.3 compatible)
@export var shape_type: int = ShapeType.CIRCLE:
	set(value):
		shape_type = value
		_update_visuals()
		_update_collision()

@export var shape_color: Color = Color(1, 0, 0):
	set(value):
		shape_color = value
		_update_visuals()

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
		_update_collision()

@export var collision_layer: int = 1
@export var collision_mask: int = 1

# These variables hold our dynamic nodes.
var visual_node: Node2D = null
var collision_body: CollisionObject2D = null

#------------------------------------------------------------------------------
# Inner Class: VisualShape
#
# This Node2D subclass is responsible for drawing the shape.
# Its _draw() method uses the current settings.
#------------------------------------------------------------------------------
class VisualShape extends Node2D:
	@export var shape_type: int = 0  # 0 for circle, 1 for rectangle
	@export var shape_color: Color = Color(1, 0, 0)
	@export var circle_radius: float = 50.0
	@export var rectangle_size: Vector2 = Vector2(100, 50)
	
	func _ready() -> void:
		# Mark for redraw.
		queue_redraw()
	
	func _draw() -> void:
		if shape_type == ShapeType.CIRCLE:
			draw_circle(Vector2.ZERO, circle_radius, shape_color)
		elif shape_type == ShapeType.RECTANGLE:
			draw_rect(Rect2(-rectangle_size / 2, rectangle_size), shape_color)

#------------------------------------------------------------------------------
# _ready()
#
# Called when the node enters the scene tree.
# We update both the visuals and collision.
#------------------------------------------------------------------------------
func _ready() -> void:
	_update_visuals()
	_update_collision()

#------------------------------------------------------------------------------
# _update_visuals()
#
# This function creates a VisualShape node that draws the shape.
# If collision is enabled, the visual node will be reparented to the physics body.
#------------------------------------------------------------------------------
func _update_visuals() -> void:
	# Remove any existing visual node.
	if visual_node:
		visual_node.queue_free()
		visual_node = null
	
	# Create a new VisualShape instance.
	visual_node = VisualShape.new()
	visual_node.name = "VisualShape"
	visual_node.shape_type = shape_type
	visual_node.shape_color = shape_color
	visual_node.circle_radius = circle_radius
	visual_node.rectangle_size = rectangle_size
	
	# If a collision body already exists, add the visual node there;
	# otherwise, add it as a direct child of this node.
	if create_collision and collision_body:
		collision_body.add_child(visual_node)
		visual_node.owner = get_tree().edited_scene_root if get_tree() else self
	else:
		add_child(visual_node)
		visual_node.owner = get_tree().edited_scene_root if get_tree() else self
	
	visual_node.queue_redraw()

#------------------------------------------------------------------------------
# _update_collision()
#
# This function creates (or re-creates) the collision object (a RigidBody2D or
# StaticBody2D) and adds a CollisionShape2D to it.
# It also reparents the visual node so that it moves along with the collision body.
#------------------------------------------------------------------------------
func _update_collision() -> void:
	_remove_existing_collision()
	
	if not create_collision:
		return
	
	# Create the collision body based on whether physics is enabled.
	if enable_physics:
		collision_body = RigidBody2D.new()
		collision_body.collision_layer = collision_layer
		collision_body.collision_mask = collision_mask
		collision_body.name = "PhysicsBody"
		collision_body.mass = 1.0
	else:
		collision_body = StaticBody2D.new()
		collision_body.name = "CollisionParent"
	
	add_child(collision_body)
	collision_body.owner = get_tree().edited_scene_root if get_tree() else self
	
	# Create and add the collision shape.
	var shape_node = CollisionShape2D.new()
	var shape: Shape2D
	if shape_type == ShapeType.CIRCLE:
		shape = CircleShape2D.new()
		shape.radius = circle_radius
	elif shape_type == ShapeType.RECTANGLE:
		shape = RectangleShape2D.new()
		shape.size = rectangle_size
	shape_node.shape = shape
	shape_node.name = "CollisionShape2D"
	collision_body.add_child(shape_node)
	shape_node.owner = get_tree().edited_scene_root if get_tree() else self
	
	# If a visual node exists, reparent it to the collision body so it follows physics.
	if visual_node:
		# Remove from its current parent...
		visual_node.get_parent().remove_child(visual_node)
		# ...and add it to the collision body.
		collision_body.add_child(visual_node)
		visual_node.owner = get_tree().edited_scene_root if get_tree() else self

#------------------------------------------------------------------------------
# _remove_existing_collision()
#
# Removes any existing collision body (RigidBody2D or StaticBody2D) to avoid duplicates.
#------------------------------------------------------------------------------
func _remove_existing_collision() -> void:
	var existing_parent = get_node_or_null("CollisionParent")
	if existing_parent:
		existing_parent.queue_free()
	var existing_physics = get_node_or_null("PhysicsBody")
	if existing_physics:
		existing_physics.queue_free()
	collision_body = null
