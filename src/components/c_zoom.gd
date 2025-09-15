# smooth_camera_zoom.gd
# Attach this script directly to your Camera2D node.

class_name SmoothCameraZoom
extends Camera2D

# --- EXPORT VARIABLES ---

@export_group("Zoom Settings")
# How quickly the camera interpolates to the target zoom. Higher is faster.
@export var zoom_speed: float = 5.0
# The amount the zoom changes with each scroll wheel tick.
@export var zoom_increment: float = 0.125
# The minimum zoom level (e.g., 0.5 is zoomed in 2x).
@export var min_zoom: float = 0.5
# The maximum zoom level (e.g., 2.0 is zoomed out 2x).
@export var max_zoom: float = 8.0

@export_group("Controls")
# If true, scroll down zooms in and scroll up zooms out.
# If false, scroll down zooms out and scroll up zooms in.
@export var invert_scroll: bool = false


# --- VARIABLES ---
var _target_zoom: Vector2 = Vector2.ONE


# --- GODOT METHODS ---

func _ready() -> void:
	# On startup, set the target zoom to the camera's current zoom level.
	# This ensures it respects any value you set in the Inspector.
	_target_zoom = self.zoom


func _unhandled_input(event: InputEvent) -> void:
	# Determine the zoom direction based on the invert_scroll flag
	var zoom_in_action = "scroll_down" if not invert_scroll else "scroll_up"
	var zoom_out_action = "scroll_up" if not invert_scroll else "scroll_down"

	# Check for zoom in action
	if event.is_action_pressed(zoom_in_action):
		# Decrease the target zoom values (zooming in)
		_target_zoom -= Vector2.ONE * zoom_increment
		get_viewport().set_input_as_handled()

	# Check for zoom out action
	if event.is_action_pressed(zoom_out_action):
		# Increase the target zoom values (zooming out)
		_target_zoom += Vector2.ONE * zoom_increment
		get_viewport().set_input_as_handled()

	# Clamp the target zoom to stay within the min/max bounds
	#_target_zoom.x = clamp(_target_zoom.x, min_zoom, max_zoom)
	#_target_zoom.y = clamp(_target_zoom.y, min_zoom, max_zoom)


func _process(delta: float) -> void:
	# In every frame, smoothly interpolate the camera's actual zoom
	# towards the target zoom. The 'delta' ensures the animation is
	# frame-rate independent.
	self.zoom = lerp(self.zoom, _target_zoom, zoom_speed * delta)
