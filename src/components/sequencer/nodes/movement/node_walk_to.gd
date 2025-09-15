# src/components/sequencer/nodes/movement/node_walk_to.gd
@tool
extends SequenceNode
class_name WalkToNode

func _ready() -> void:
	# Force this node's movement mode to WALK by default.
	move_mode = MoveMode.WALK
