# src/components/sequencer/nodes/flow/node_switch_sequence.gd
@tool
extends SequenceNode
class_name SwitchSequenceNode

## Accept either the RUNNER name ("DemoSequence") or the CONTAINER name ("Goobie_DemoSequence").
@export var new_sequence_name: StringName

func _on_action(target: Node2D) -> void:
	var manager: SequenceManager = null
	for c in target.get_children():
		if c is SequenceManager:
			manager = c
			break

	if manager == null:
		push_warning("SwitchSequenceNode: No SequenceManager on '%s'." % target.name)
		emit_signal("completed")
		return

	var desired := String(new_sequence_name)

	# If it's already a runner name, use it.
	if manager.has_runner(desired):
		manager.call_deferred("switch_sequence", desired)
		emit_signal("completed")
		return

	# Otherwise, try to resolve by CONTAINER name -> find the runner that points to that container.
	var resolved_runner: StringName = ""
	for c in target.get_children():
		if c is SequenceRunnerComponent:
			var r := c as SequenceRunnerComponent
			var cont := r.get_sequence_container_node()
			if cont and cont.name == desired:
				resolved_runner = r.name
				break

	if resolved_runner != "":
		manager.call_deferred("switch_sequence", resolved_runner)
	else:
		push_error("SwitchSequenceNode: Could not resolve '%s' to a runner on '%s'." % [desired, target.name])

	# Always complete so the current runner doesn't hang waiting.
	emit_signal("completed")
