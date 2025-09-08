@tool
class_name CGuiScale
extends Node

########################################################################################
## A component that adds animated scaling effects to its parent Control or Node2D node.
## To use: Add this node as a child of any Control or Node2D-based node (Button, Sprite2D, etc.).
## For hover effects on non-Control nodes, the parent must have an Area2D or other collision shape
## to emit "mouse_entered" and "mouse_exited" signals.
########################################################################################

@export_group("Hover Effect")
## If enabled, the parent control will scale up when hovered.
@export var enable_hover_effect: bool = true
## The target scale to animate towards on mouse enter.
@export var hover_scale: float = 1.1
## The time it takes to animate the scale up or down, in seconds. 0 = instant.
@export var transition_duration: float = 0.1

@export_group("Pulse Effect")
## If enabled, the control will continuously scale up and down.
@export var enable_pulse_effect: bool = false
## The minimum scale in the pulse cycle.
@export var pulse_min_scale: float = 1.0
## The maximum scale in the maximum cycle.
@export var pulse_max_scale: float = 1.05
## The time it takes to complete one full pulse cycle (min -> max -> min).
@export var pulse_duration: float = 2.0

# Store a typed reference to the parent for performance and type safety.
var _parent_node: CanvasItem

# Tweens animate properties smoothly over time.
var _tween: Tween

# Track if the mouse is currently over the parent control.
var _is_hovered: bool = false

# When true, prevent dynamic animations & responses (for one-shot GUI scaling rather than Mouse-Event responses)
var _is_locked: bool = false


func _ready() -> void:
	# Check for CanvasItem instead of just Control.
	var parent = get_parent()
	if not parent is CanvasItem:
		push_error("CGuiScale component must be a child of a CanvasItem-derived node (e.g., Control, Node2D, Sprite2D).")
		set_process(false)
		return
	_parent_node = parent

	# Apply pivot logic only to Control nodes, as Node2D/Sprite2D don't have it.
	if _parent_node is Control:
		# Wait for parent to be resized before calculating its center.
		await _parent_node.resized
		_parent_node.pivot_offset = _parent_node.size / 2.0
	# For Node2D (like Sprite2D), scaling is relative to the node's origin.
	# To scale from the center, ensure the Sprite2D's 'centered' property is on,
	# or adjust its 'offset' manually in the Inspector.

	# Check if the parent has the necessary signals before connecting.
	# This allows the hover effect to work on any node that provides these signals (e.g., Control, Area2D).
	if _parent_node.has_signal("mouse_entered") and _parent_node.has_signal("mouse_exited"):
		_parent_node.mouse_entered.connect(_on_mouse_entered)
		_parent_node.mouse_exited.connect(_on_mouse_exited)
	elif enable_hover_effect:
		push_warning("Hover effect is enabled, but the parent node does not have 'mouse_entered'/'mouse_exited' signals. " +
					 "To enable this for a Sprite2D, place it inside an Area2D and attach this component to the Area2D.")

	# Set the initial animation state.
	_update_animation_state()


# --- State Machine & Animation Control ---

func _update_animation_state() -> void:
	if _is_locked:
		return
	
	if _tween:
		_tween.kill()

	if _is_hovered and enable_hover_effect:
		_animate_to_hover()
	elif enable_pulse_effect:
		_animate_to_pulse()
	else:
		_animate_to_idle()

# --- Animations ---

func pop_in():
	_is_locked = true
	if _tween: _tween.kill()

	_tween = create_tween().set_parallel()
	_tween.tween_property(_parent_node, "scale", Vector2.ONE, 0.2).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_SPRING)
	_tween.tween_property(_parent_node, "modulate:a", 1.0, 0.1).from(0.0)
	
	await _tween.finished
	_is_locked = false
	_update_animation_state()


func pop_out():
	_is_locked = true
	if _tween: _tween.kill()

	_tween = create_tween()
	_tween.tween_property(_parent_node, "modulate:a", 0.0, 0.1)

	await _tween.finished
	_is_locked = false
	_update_animation_state()


# --- Specific Animation Functions ---

func _animate_to_hover() -> void:
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_parent_node, "scale", Vector2.ONE * hover_scale, transition_duration)

func _animate_to_pulse() -> void:
	_tween = create_tween().set_loops()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_parent_node, "scale", Vector2.ONE * pulse_max_scale, pulse_duration / 2.0)
	_tween.tween_property(_parent_node, "scale", Vector2.ONE * pulse_min_scale, pulse_duration / 2.0)

func _animate_to_idle() -> void:
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_parent_node, "scale", Vector2.ONE, transition_duration)


# --- Signal Callbacks ---

func _on_mouse_entered() -> void:
	_is_hovered = true
	_update_animation_state()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_update_animation_state()
