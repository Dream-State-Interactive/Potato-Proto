# c_gui_scale.gd
@tool
class_name CGuiScale
extends Node

########################################################################################
## A component that adds animated scaling effects to its parent Control node.
## To use: Add this node as a child of any Control-based node (Button, Panel, VBoxContainr, THE WORKS).
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
var _parent_control: Control

# Tweens animate properties smoothly over time.
var _tween: Tween

# Track if the mouse is currently over the parent control.
var _is_hovered: bool = false

# When true, prevent dynamic animations & responses (for one-shot GUI scaling rather than Mouse-Event responses)
var _is_locked: bool = false


func _ready() -> void:
	# Get parent node and verify it's a Control.
	_parent_control = get_parent()
	if not _parent_control is Control:
		push_error("CGuiScale component must be a child of a Control node.")
		set_process(false)
		return

	# Wait for parent to be resized before calculating its center.
	await _parent_control.resized
	_parent_control.pivot_offset = _parent_control.size / 2.0

	# Always connect signals if the hover effect is possible.
	# The logic to enable/disable is handled by state machine.
	_parent_control.mouse_entered.connect(_on_mouse_entered)
	_parent_control.mouse_exited.connect(_on_mouse_exited)

	# Set the initial animation state.
	_update_animation_state()


# --- State Machine & Animation Control ---

# This decides which animation to play based on the current state (_is_hovered, enable_pulse_effect, etc.).
func _update_animation_state() -> void:
	# 0. Prevent dynamic responses if locked
	if _is_locked:
		return
	
	# 1. Stop any animation that is currently running.
	if _tween:
		_tween.kill()

	# 2. Decide which new animation to start.
	# Priority 1: Hover effect. If the mouse is over the control, it takes precedence.
	if _is_hovered and enable_hover_effect:
		_animate_to_hover()
	# Priority 2: Pulse effect. If not hovering, but pulsing is enabled, do that.
	elif enable_pulse_effect:
		_animate_to_pulse()
	# Priority 3: Default/Idle state. If no other effects are active, return to normal scale.
	else:
		_animate_to_idle()

# --- Animations ---

## Fades and scales the parent control in. Temporarily disables interactive effects.
func pop_in():
	# 1. Lock the component to prevent interference.
	_is_locked = true
	if _tween: _tween.kill()

	# 2. Run the animation.
	_tween = create_tween().set_parallel()
	_tween.tween_property(_parent_control, "scale", Vector2.ONE, 0.2).from(Vector2(0.8, 0.8)).set_trans(Tween.TRANS_SPRING)
	_tween.tween_property(_parent_control, "modulate:a", 1.0, 0.1).from(0.0)
	
	# 3. Wait for it to finish, then unlock and restore the correct interactive state.
	await _tween.finished
	_is_locked = false
	_update_animation_state()


## Fades the parent control out. Temporarily disables interactive effects.
func pop_out():
	# 1. Lock the component.
	_is_locked = true
	if _tween: _tween.kill()

	# 2. Run the animation.
	_tween = create_tween()
	_tween.tween_property(_parent_control, "modulate:a", 0.0, 0.1)

	# 3. Wait for it to finish, then unlock and restore the correct interactive state.
	await _tween.finished
	_is_locked = false
	_update_animation_state()


# --- Specific Animation Functions ---

func _animate_to_hover() -> void:
	# Create a new one-shot tween to scale up to the hover_scale.
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_parent_control, "scale", Vector2.ONE * hover_scale, transition_duration)

func _animate_to_pulse() -> void:
	# Create a new looping tween for the pulse effect.
	_tween = create_tween().set_loops()
	_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_parent_control, "scale", Vector2.ONE * pulse_max_scale, pulse_duration / 2.0)
	_tween.tween_property(_parent_control, "scale", Vector2.ONE * pulse_min_scale, pulse_duration / 2.0)

func _animate_to_idle() -> void:
	# Create a new one-shot tween to return to the default scale.
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	_tween.tween_property(_parent_control, "scale", Vector2.ONE, transition_duration)


# --- Signal Callbacks ---

func _on_mouse_entered() -> void:
	# Set the state to "hovered" and tell the state machine to update.
	_is_hovered = true
	_update_animation_state()

func _on_mouse_exited() -> void:
	# Set the state to "not hovered" and tell the state machine to update.
	_is_hovered = false
	_update_animation_state()
