# c_sequence_runner.gd
# Attach this node as a child to the object you want to control (e.g., your NPC).
# It executes a linear list of SequenceNode children from a container (sequence_path).
extends Node
class_name SequenceRunnerComponent

@export var sequence_path: NodePath
@export var loop: bool = false
@export var autostart_if_no_manager: bool = true
@export var is_default_runner: bool = false

var current_sequence_node_index: int = 0
var sequence_nodes: Array[Node] = []
var actor: Node2D
var _active: bool = false
var _current_node: SequenceNode = null
var _initialized: bool = false
var _sequence_container: Node = null
var _pending_next_override: Variant = null
var _advance_is_scheduled: bool = false

func _ready() -> void:
	if not _has_sibling_manager() and autostart_if_no_manager:
		var default_runner = _find_default_runner_sibling()
		if default_runner == self:
			start(true)

func initialize_if_needed() -> void:
	if _initialized: return
	actor = get_parent()
	if not sequence_path.is_empty():
		var path_node := get_node_or_null(sequence_path)
		if path_node:
			_sequence_container = path_node
			for child in path_node.get_children():
				if child is SequenceNode:
					sequence_nodes.append(child)
	_initialized = true

func get_sequence_container_node() -> Node:
	initialize_if_needed()
	if _sequence_container:
		return _sequence_container
	if not sequence_path.is_empty():
		return get_node_or_null(sequence_path)
	return null

func start(reset: bool = true) -> void:
	print("RUNNER '%s': Received START command." % name)
	initialize_if_needed()

	if not _active:
		_active = true
	
	if reset:
		print("RUNNER '%s': Resetting index to 0." % name)
		current_sequence_node_index = 0
	
	_pending_next_override = null
	_execute_next_sequence_node()

func stop() -> void:
	if not _active:
		return
	print("RUNNER '%s': Received STOP command." % name)
	_active = false
	_pending_next_override = null
	_advance_is_scheduled = false
	if is_instance_valid(_current_node) and _current_node.is_connected("completed", Callable(self, "_on_sequence_node_completed")):
		_current_node.completed.disconnect(Callable(self, "_on_sequence_node_completed"))
	_current_node = null
	print("RUNNER '%s': Is now inactive." % name)

func _execute_next_sequence_node() -> void:
	if not _active:
		return
	if sequence_nodes.is_empty():
		stop()
		return
	if current_sequence_node_index < sequence_nodes.size():
		var node: Node = sequence_nodes[current_sequence_node_index]
		if node is SequenceNode:
			_current_node = node
			_current_node.completed.connect(_on_sequence_node_completed, CONNECT_ONE_SHOT)
			_current_node.execute(actor)
		else:
			_on_sequence_node_completed()
	elif loop:
		current_sequence_node_index = 0
		_execute_next_sequence_node()
	else:
		stop()

func _has_sibling_manager() -> bool:
	var p: Node = get_parent()
	if p == null: return false
	for c in p.get_children():
		if c is SequenceManager:
			return true
	return false

func _find_default_runner_sibling() -> SequenceRunnerComponent:
	var p: Node = get_parent()
	if p == null: return self
	var first: SequenceRunnerComponent = null
	for c in p.get_children():
		if c is SequenceRunnerComponent:
			if first == null: first = c
			if (c as SequenceRunnerComponent).is_default_runner:
				return c
	return first if first != null else self

func _on_sequence_node_completed(next_override: Variant = null) -> void:
	if not _active:
		return
	
	_pending_next_override = next_override
	
	if not _advance_is_scheduled:
		_advance_is_scheduled = true
		call_deferred("_advance_to_next_node")

func _advance_to_next_node() -> void:
	_advance_is_scheduled = false
	if not _active:
		return

	var next_idx: int = _resolve_next_index(_pending_next_override)
	_pending_next_override = null

	if next_idx < 0:
		push_warning("Runner '%s': could not resolve next node. Stopping sequence." % name)
		stop()
		return
	
	current_sequence_node_index = next_idx
	_execute_next_sequence_node()

func _resolve_next_index(override: Variant) -> int:
	if override is Node:
		return _index_for_node(override as Node)
	
	if override is NodePath and not (override as NodePath).is_empty():
		var base: Node = (_current_node if is_instance_valid(_current_node) else self)
		var resolved_node: Node = base.get_node_or_null(override as NodePath)
		if resolved_node == null and _sequence_container != null:
			resolved_node = _sequence_container.get_node_or_null(override as NodePath)
		
		if resolved_node:
			return _index_for_node(resolved_node)
		
		push_warning("Runner '%s': override path '%s' not found." % [name, str(override)])

	return current_sequence_node_index + 1

func _index_for_node(n: Node) -> int:
	if n == null:
		return -1
	var idx: int = sequence_nodes.find(n)
	if idx != -1:
		return idx
	if _sequence_container == null:
		return -1
	var cur: Node = n
	while cur != null and cur.get_parent() != _sequence_container:
		cur = cur.get_parent()
	if cur != null and cur.get_parent() == _sequence_container:
		return sequence_nodes.find(cur)
	return -1
