@tool
extends Node2D

enum ShapeType {
	CIRCLE,
	RECTANGLE
}

@export var shape_type: ShapeType = ShapeType.CIRCLE # Default to circle
@export var shape_color: Color = Color(1, 0, 0) # Red by default
@export var circle_radius: float = 50.0
@export var rectangle_size: Vector2 = Vector2(100, 50)

func _draw():
	if shape_type == ShapeType.CIRCLE:
		draw_circle(Vector2(0, 0), circle_radius, shape_color)
	elif shape_type == ShapeType.RECTANGLE:
		draw_rect(Rect2(-rectangle_size / 2, rectangle_size), shape_color) # Center the rectangle

func _ready():
	set_process_mode(Node.PROCESS_MODE_ALWAYS)

func _process(_delta):
	queue_redraw()
