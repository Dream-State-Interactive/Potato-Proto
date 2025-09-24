# src/levels/zoo/zoo_theme_generator.gd
extends Node2D
class_name ZooThemeGenerator

@export var theme_order: Array[ThemeData] = []                # drag your .tres here in order
@export var segment_scene: PackedScene                         # res://src/levels/zoo/ThemeSegment.tscn
@export var start_anchor_path: NodePath                        # optional Marker2D/Node2D to start at
@export_range(1, 5, 1) var max_active_segments: int = 2
@export var seam_eps_px: float = 2.0

@export var start_time_of_day: float = 0.25
@export var advance_time_per_segment: float = 0.0              # e.g. 0.15 to roll time
@export var crossfade: bool = false
@export var crossfade_seconds: float = 1.2

var _base_global: Vector2 = Vector2.ZERO
var _next_spawn_x: float = 0.0
var _theme_index: int = 0
var _active: Array[ThemeSegment] = []

func _ready() -> void:
	if theme_order.is_empty():
		push_warning("ZooThemeGenerator: theme_order is empty.")
		return
	if segment_scene == null:
		push_error("ZooThemeGenerator: segment_scene is null.")
		return

	ThemeManager.set_time_of_day(start_time_of_day)
	var first_theme: ThemeData = theme_order[_theme_index]
	ThemeManager.apply_theme(first_theme)

	var anchor: Node2D = get_node_or_null(start_anchor_path) as Node2D
	_base_global = anchor.global_position if anchor else global_position

	# first segment + first theme
	_spawn_segment_with_theme(theme_order[_theme_index])

func _spawn_segment_with_theme(theme: ThemeData) -> void:
	var seg := segment_scene.instantiate() as ThemeSegment
	add_child(seg)
	seg.global_position = _base_global + Vector2(_next_spawn_x, 0.0)
	seg.end_reached.connect(_on_segment_end)
	seg.apply_theme_once(theme)                        # freeze its look
	_active.append(seg)
	_next_spawn_x += seg.length_px + seam_eps_px
	_cull_if_needed()

func _on_segment_end(seg: ThemeSegment) -> void:
	_theme_index = (_theme_index + 1) % theme_order.size()
	var next_theme := theme_order[_theme_index]

	# spawn next first (no gap), then switch the global look
	_spawn_segment_with_theme(next_theme)

	if advance_time_per_segment != 0.0:
		var new_t := wrapf(ThemeManager.time_of_day + advance_time_per_segment, 0.0, 1.0)
		ThemeManager.set_time_of_day(new_t)

	_apply_theme_global(next_theme)

func _apply_theme_global(t: ThemeData) -> void:
	if crossfade:
		ThemeManager.transition_to_theme(t, crossfade_seconds)
	else:
		ThemeManager.apply_theme(t)


func _cull_if_needed() -> void:
	while _active.size() > max_active_segments:
		var oldest: ThemeSegment = _active.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
