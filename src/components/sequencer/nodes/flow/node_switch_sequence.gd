# src/components/sequencer/nodes/flow/node_switch_sequence.gd
@tool
extends SequenceNode
class_name SwitchSequenceNode

## The name of the SequenceRunner sibling to switch to.
@export var new_sequence_name: StringName

func _on_action(target: Node2D) -> void:
	# Find the SequenceManager on the actor by its class, not its name.
	var manager: SequenceManager = null
	for child in target.get_children():
		if child is SequenceManager:
			manager = child
			break # Found it

	if manager:
		# --- THE DEFINITIVE FIX ---
		# Defer the call to switch_sequence. This allows the current runner's
		# execution of this node to fully complete before the manager steps in.
		manager.call_deferred("switch_sequence", new_sequence_name)
		
		# CRUCIALLY, we DO NOT emit the "completed" signal.
		# The manager is now in charge of stopping this runner. We don't want
		# this runner to simultaneously try to advance to its next node, which
		# created the original problem. It will be left waiting for a signal
		# that never comes, which is fine because the manager will stop it
		# moments later.
	else:
		push_warning("SwitchSequenceNode: No SequenceManager component found on actor '%s'." % target.name)
		# If there's no manager, we must complete, otherwise the sequence hangs.
		emit_signal("completed")
