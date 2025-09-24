# src/components/sequencer/nodes/action/node_set_property.gd
@tool
extends SequenceNode
class_name SetPropertyNode

@export_group("Target")
## The node to modify. If empty, it will target the actor running the sequence.
@export var target_node_path: NodePath
## The property to change (e.g., "visible", "modulate", "scale.x").
@export var property_path: String

@export_group("Value")
## The new value for the property.
## Add ONE element to this array of the correct type.
@export var value_array: Array

@export_group("Transition")
## How long the change should take. If 0, the change is instant.
@export var transition_duration: float = 0.0

func _on_action(target: Node2D) -> void:
	var node_to_modify = target
	if not target_node_path.is_empty():
		node_to_modify = get_node_or_null(target_node_path)

	if not is_instance_valid(node_to_modify):
		push_warning("SetPropertyNode: Target node is not valid.")
		emit_signal("completed")
		return

	# Check if the user has provided a value.
	if value_array.is_empty():
		push_warning("SetPropertyNode: 'Value Array' is empty. Nothing to set.")
		emit_signal("completed")
		return
		
	# Get the first element from the array as our value.
	var value_to_set = value_array[0]

	if transition_duration > 0:
		# Tweening only works on specific data types.
		if typeof(value_to_set) in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_COLOR, TYPE_INT]:
			var tween = create_tween()
			tween.tween_property(node_to_modify, property_path, value_to_set, transition_duration)
			await tween.finished
		else:
			# If the type can't be tweened, apply it instantly.
			push_warning("SetPropertyNode: Cannot tween property of type %s. Setting instantly." % typeof(value_to_set))
			node_to_modify.set(property_path, value_to_set)
	else:
		node_to_modify.set(property_path, value_to_set)
	
	emit_signal("completed")
