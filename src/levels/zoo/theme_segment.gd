# src/levels/zoo/theme_segment.gd
extends Node2D
class_name ThemeSegment

signal end_reached(segment: ThemeSegment)

@export var length_px: float = 5000.0
@export var ground_height_px: float = 120.0
@export var ground_y: float = 300.0
@export var end_margin_px: float = 96.0
@export var player_group: StringName = &"player"

@export var end_trigger_extra_height: float = 400.0    # extra catcher height
@export var end_trigger_y_offset: float = -60.0        # move the trigger up a bit
@export_flags_2d_physics var end_trigger_layer: int = 1
@export_flags_2d_physics var end_trigger_mask: int = 1

# created at runtime
var _fill: Polygon2D
var _trim: Line2D
var _body: StaticBody2D
var _col: CollisionPolygon2D
var _end: Area2D

func _ready() -> void:
	add_to_group("theme_segments")
	_build_geo()
	_build_end_trigger()


func apply_theme_once(theme: ThemeData) -> void:
	if theme == null: return
	if _fill: _fill.modulate = theme.terrain_fill
	if _trim: _trim.default_color = theme.terrain_trim

func _build_geo() -> void:
	# Ground polygon: a simple rectangle
	var p0 := Vector2(0.0, ground_y)
	var p1 := Vector2(length_px, ground_y)
	var p2 := Vector2(length_px, ground_y + ground_height_px)
	var p3 := Vector2(0.0, ground_y + ground_height_px)
	var poly := PackedVector2Array([p0, p1, p2, p3])

	_fill = Polygon2D.new()
	_fill.polygon = poly
	_fill.antialiased = true
	add_child(_fill)

	_trim = Line2D.new()
	_trim.points = PackedVector2Array([p0, p1])
	_trim.width = 4.0
	_trim.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trim.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_trim)

	_body = StaticBody2D.new()
	_col = CollisionPolygon2D.new()
	_col.polygon = poly
	_body.add_child(_col)
	add_child(_body)

func _build_end_trigger() -> void:
	_end = Area2D.new()

	var shape := RectangleShape2D.new()
	shape.size = Vector2(64.0, ground_height_px + end_trigger_extra_height)

	var cs := CollisionShape2D.new()
	cs.shape = shape
	_end.add_child(cs)

	# Center it near the ground, then nudge up by end_trigger_y_offset
	_end.position = Vector2(
		length_px - end_margin_px,
		ground_y + ground_height_px * 0.5 + end_trigger_y_offset
	)

	# Make sure it actually collides with your player’s layer/mask
	_end.collision_layer = end_trigger_layer
	_end.collision_mask  = end_trigger_mask

	add_child(_end)
	_end.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if player_group == StringName("") or body.is_in_group(player_group):
		end_reached.emit(self)
