# src/components/sequencer/conditions/condition_player_in_area.gd
extends Condition
class_name ConditionPlayerInArea

@export var area_path: NodePath
@export var required_group: StringName = &"player"  # leave empty to accept any body
@export var debug: bool = false

var _area: Area2D
var _is_inside: bool = false
var _bound: bool = false
var _actor: Node2D = null

func bind(actor: Node2D) -> void:
	_actor = actor
	_area = _resolve_area_from(actor)
	if _area == null:
		_bound = false
		if debug:
			push_warning("PlayerInArea: could not resolve Area2D from '%s'." % str(area_path))
		return

	_area.monitoring = true
	_is_inside = _compute_current_overlap(_area)

	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	if not _area.body_exited.is_connected(_on_body_exited):
		_area.body_exited.connect(_on_body_exited)

	_bound = true
	if debug:
		var cs: Node = _actor.get_tree().current_scene
		var scene_name: StringName = (cs.name if cs != null else &"?")
		print("PlayerInArea: bound to %s (scene=%s) initial_inside=%s"
			% [_area.get_path(), scene_name, str(_is_inside)])

func check(actor: Node2D) -> bool:
	if not _bound or not is_instance_valid(_area):
		bind(actor)
	if _area and not _is_inside:
		_is_inside = _compute_current_overlap(_area)
	return _is_inside

func _on_body_entered(body: Node) -> void:
	if required_group.is_empty() or body.is_in_group(required_group):
		_is_inside = true

func _on_body_exited(body: Node) -> void:
	if required_group.is_empty() or body.is_in_group(required_group):
		_is_inside = _compute_current_overlap(_area)

func _compute_current_overlap(a: Area2D) -> bool:
	if a == null:
		return false
	if required_group.is_empty():
		return not a.get_overlapping_bodies().is_empty()
	for b in a.get_overlapping_bodies():
		if b.is_in_group(required_group):
			return true
	return false

func _resolve_area_from(actor: Node) -> Area2D:
	if area_path.is_empty():
		return null

	# Absolute (e.g., "/root/SequenceDemo/TriggerZone")
	if area_path.is_absolute():
		var root_node: Node = actor.get_tree().root
		return root_node.get_node_or_null(area_path) as Area2D

	# Walk up from actor until a parent has this relative path
	var base: Node = actor
	while base:
		if base.has_node(area_path):
			return base.get_node(area_path) as Area2D
		base = base.get_parent()

	# Fallback: current scene (common when Area2D is a sibling)
	var cs: Node = actor.get_tree().current_scene
	if cs and cs.has_node(area_path):
		return cs.get_node(area_path) as Area2D

	return null
