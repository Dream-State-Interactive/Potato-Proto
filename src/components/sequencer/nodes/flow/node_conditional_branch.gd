# src/components/sequencer/nodes/flow/node_conditional_branch.gd
@tool
extends SequenceNode
class_name ConditionalBranchNode

@export var condition: Condition
## The node to jump to if the condition is true.
@export var path_if_true: NodePath
## The node to jump to if the condition is false.
## If this is empty, it will proceed to the next node in the sequence.
## If this points to THIS node, it will wait here until the condition becomes true.
@export var path_if_false: NodePath

var _target_actor: Node2D

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var tn := _resolve_path(path_if_true)
	if tn is Node2D:
		draw_line(Vector2.ZERO, to_local(tn.global_position), Color.GREEN, 2.0)
	var fn := _resolve_path(path_if_false)
	if fn is Node2D:
		draw_line(Vector2.ZERO, to_local(fn.global_position), Color.RED, 2.0)

func _on_action(target: Node2D) -> void:
	_target_actor = target

	# Ensure the condition is unique per scene instance (no shared state across NPCs)
	if condition != null and not condition.resource_local_to_scene:
		condition = condition.duplicate()    # runtime-unique
		condition.resource_local_to_scene = true

	# Optional eager bind (safe even if condition will lazy-bind)
	if condition and condition.has_method("bind"):
		condition.bind(target)

	# If no valid condition, fall through false (or next if empty)
	if not (condition is Condition):
		push_warning("ConditionalBranchNode '%s': No valid Condition resource assigned." % name)
		var fn = _resolve_path(path_if_false)
		print("ConditionalBranchNode '%s': No condition, taking false path to: %s" % [name, fn])
		emit_signal("completed", fn)
		return

	# --- Main Logic with Debugging ---
	print("ConditionalBranchNode '%s': Checking condition..." % name)
	if condition.check(target):
		var tn = _resolve_path(path_if_true)
		print("...Condition is TRUE. Jumping to node: %s" % [tn])
		emit_signal("completed", tn)
		return
	else:
		print("...Condition is FALSE.")
		var fn = _resolve_path(path_if_false)
		
		# Check for the special "wait" case where the false path loops back on itself.
		if fn == self:
			print("...False path points to self. WAITING for condition to become true.")
			await _wait_until_true()
			# Once the wait is over, the condition is now true, so we take the true path.
			var tn_after_wait = _resolve_path(path_if_true)
			print("...Condition is now TRUE. Jumping to node: %s" % [tn_after_wait])
			emit_signal("completed", tn_after_wait)
		else:
			# Otherwise, take the designated false path.
			# If fn is null (because the path is empty or invalid), the runner will correctly
			# default to the next sequential node.
			print("...Jumping to false-path node: %s" % [fn])
			emit_signal("completed", fn)

# Simple, robust resolver that works for relative and absolute paths
func _resolve_path(p: NodePath) -> Node:
	if p.is_empty():
		return null
	if p.is_absolute():
		return get_tree().root.get_node_or_null(p)
	# Try relative to this node first, then walk up until someone has it
	var base: Node = self
	while base:
		if base.has_node(p):
			return base.get_node(p)
		base = base.get_parent()
	return null

func _wait_until_true() -> void:
	# Safety: break if actor disappears; Condition will (re)bind lazily if needed
	while is_instance_valid(_target_actor) and not condition.check(_target_actor):
		await get_tree().physics_frame
