# Filename: res://addons/angle_editor_plugin/angle_gizmo_2d.gd

## A reusable "smart" gizmo component that draws visuals for its parent node.
## To use, add this node as a child to any Node2D. It will automatically:
## 1. Find the first property on its parent ending in "_angle" and draw a red arrow.
## 2. Find a property on its parent named "push_origin_offset" and draw a cyan handle.
@tool
extends Node2D

# --- State variables to track which properties the parent has ---
var _angle_property: StringName
var _origin_property: StringName = "push_origin_offset" # We look for this specific name.

# Called when this node enters the scene tree in the editor.
func _enter_tree() -> void:
	# Immediately try to find the properties we care about on the parent.
	_find_target_properties()

## Inspects the parent node and finds the properties this gizmo should track.
func _find_target_properties() -> void:
	var parent = get_parent()
	if not parent: return

	# Reset before searching.
	_angle_property = ""
	var has_origin_prop = false

	# Iterate through all of the parent's exported properties.
	for prop in parent.get_property_list():
		# Find the first float property that ends with our naming convention.
		if _angle_property.is_empty() and prop.type == TYPE_FLOAT and prop.name.ends_with("_angle"):
			_angle_property = prop.name
		
		# Separately, check if the parent has the specific origin offset property.
		if prop.name == _origin_property and prop.type == TYPE_VECTOR2:
			has_origin_prop = true

	# If the parent doesn't have the origin property, we clear our variable so we don't try to draw it.
	if not has_origin_prop:
		_origin_property = ""

# Godot's built-in drawing function, which runs in the editor because of @tool.
func _draw() -> void:
	# Don't draw if the game is running.
	if not Engine.is_editor_hint(): return
	
	var parent = get_parent()
	if not parent: return
		
	# --- Draw the Directional Arrow ---
	# Only draw if we successfully found an angle property to track.
	if not _angle_property.is_empty():
		var angle_degrees = float(parent.get(_angle_property))
		var direction = Vector2.from_angle(deg_to_rad(angle_degrees))
		
		draw_line(Vector2.ZERO, direction * 30, Color.RED, 2.0)
		draw_line(direction * 30, direction * 20 + direction.orthogonal() * 5, Color.RED, 2.0)
		draw_line(direction * 30, direction * 20 - direction.orthogonal() * 5, Color.RED, 2.0)
	
	# --- Draw the Origin Handle ---
	# Only draw if we successfully found the origin offset property.
	if not _origin_property.is_empty():
		var origin_offset: Vector2 = parent.get(_origin_property)
		draw_circle(origin_offset, 6.0, Color.CYAN)
		draw_circle(origin_offset, 4.0, Color.WHITE)

# Called every frame.
func _process(_delta):
	# In the editor, continuously request a redraw. This ensures the gizmo updates
	# in real-time when the parent's properties are changed in the Inspector.
	if Engine.is_editor_hint():
		queue_redraw()
