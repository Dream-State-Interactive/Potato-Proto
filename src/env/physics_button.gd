# src/env/physics_button.gd

#@tool
extends Node2D
class_name PhysicsButton

signal pressed

@export var button_id: StringName = "button_1"
@export var stay_pressed: bool = true
@export var trigger_margin_px: float = 3.0      # near-bottom margin
@export var min_press_depth_px: float = 6.0     # must travel at least this much to count

@onready var pressing_button: RigidBody2D = $PressingButton
@onready var groove_joint: GrooveJoint2D = $GrooveJoint2D

var is_pressed: bool = false
var _start_local: Vector2
var _max_depth: float = 0.0                      # deepest travel seen since last release

func _ready() -> void:
	_start_local = groove_joint.to_local(pressing_button.global_position)
	# safety
	if groove_joint.node_b != pressing_button.get_path():
		groove_joint.node_b = pressing_button.get_path()
	pressing_button.lock_rotation = true          # prevents see-saw per RigidBody2D docs. :contentReference[oaicite:1]{index=1}

func _physics_process(_dt: float) -> void:
	if is_pressed and stay_pressed:
		return

	var depth := _axis_depth()
	if depth > _max_depth:
		_max_depth = depth

	# Trigger when we’re close to the deepest point we've actually hit
	var target := maxf(_max_depth - trigger_margin_px, min_press_depth_px)
	if not is_pressed and depth >= target:
		_activate_button()


	if int(Engine.get_physics_frames()) % 6 == 0:
		print("depth=", depth, "  max=", _max_depth, "  target=", target)

func _axis_depth() -> float:
	# Use whichever local axis actually changes more (X vs Y).
	var lp := groove_joint.to_local(pressing_button.global_position)
	var dx := absf(lp.x - _start_local.x)
	var dy := absf(lp.y - _start_local.y)
	return maxf(dx, dy)

func _activate_button() -> void:
	is_pressed = true
	print("Button '%s' pressed (depth≈%.2f px)" % [button_id, _max_depth])
	pressed.emit()
	if stay_pressed:
		pressing_button.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		pressing_button.freeze = true   # Godot 4 freeze/freeze_mode. :contentReference[oaicite:2]{index=2}
