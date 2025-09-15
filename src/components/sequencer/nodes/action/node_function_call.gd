# src/components/sequencer/nodes/action/node_function_call.gd
@tool
extends SequenceNode
class_name FunctionCallNode

@export var target_node_path: NodePath
@export var function_name: StringName
## An array of arguments to pass to the function.
@export var arguments: Array

func _on_action(target: Node2D) -> void:
	var node_to_call = get_node_or_null(target_node_path)
	if not is_instance_valid(node_to_call):
		push_warning("FunctionCallNode: Target node is not valid.")
		emit_signal("completed")
		return
	
	if node_to_call.has_method(function_name):
		node_to_call.callv(function_name, arguments)
	else:
		push_warning("FunctionCallNode: Method '%s' not found on target node." % function_name)
		
	emit_signal("completed")
