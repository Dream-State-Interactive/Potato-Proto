# src/components/sequencer/nodes/flow/node_goto.gd
@tool
extends SequenceNode
class_name GoToNode

@export var target_node_in_sequence: NodePath

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var t := get_node_or_null(target_node_in_sequence)
	if t is Node2D:
		draw_line(Vector2.ZERO, to_local(t.global_position), Color.GREEN, 2.0)

func _on_action(_target: Node2D) -> void:
	emit_signal("completed", get_node_or_null(target_node_in_sequence))
