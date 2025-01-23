@tool
extends StaticBody2D


func _ready() -> void:
	makeShape()
	

func makeShape() -> void:
	var curve = $Path2D.curve
	var polygon = curve.get_baked_points()

	  
	$Polygon2D.polygon = polygon
	$Line2D.points = polygon

	$CollisionPolygon2D.polygon = polygon

func _process(delta):
	makeShape()
	$Polygon2D.queue_redraw()
	$Line2D.queue_redraw()
