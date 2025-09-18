# src/modes/gauntlet/segment_boundary.gd
class_name SegmentBoundary
extends Area2D

signal player_crossed_boundary(from_index: int, direction: int)

var segment_index: int = 0
var _enter_side: Dictionary = {}   # instance_id(int) -> side(int)

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _seam_x() -> float:
	return global_position.x

func _side_of(body: Node) -> int:
	var node2d := body as Node2D
	if node2d == null:
		return 0
	var dx: float = node2d.global_position.x - _seam_x()
	if dx > 0.0:
		return 1
	elif dx < 0.0:
		return -1
	return 0

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not (body is PhysicsBody2D):
		return
	var id: int = body.get_instance_id()
	var s: int = _side_of(body)
	_enter_side[id] = s

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not (body is PhysicsBody2D):
		return

	var id: int = body.get_instance_id()
	var side_enter: int = int(_enter_side.get(id, 0))  # cast Variant -> int
	var side_exit: int = _side_of(body)

	# True crossing only when sides differ
	if side_enter != 0 and side_exit != 0 and side_enter != side_exit:
		var direction: int = (1 if (side_enter == -1 and side_exit == 1) else -1)

		# Safety fallback (kept for completeness)
		if side_enter == side_exit:
			var velx: float = (body as PhysicsBody2D).linear_velocity.x
			direction = (1 if velx >= 0.0 else -1)

		var from_index: int = (segment_index if direction > 0 else segment_index + 1)
		emit_signal("player_crossed_boundary", from_index, direction)

	_enter_side.erase(id)
