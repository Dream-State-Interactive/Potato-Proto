# src/components/sequencer/c_sequence_node.gd
@tool
extends Node2D
class_name SequenceNode

enum MoveMode { NONE, WALK, TELEPORT }

signal completed(next_node_override)

@export_group("Movement")
## How the actor should move to this node before the action runs.
@export var move_mode: MoveMode = MoveMode.WALK
## The speed to use if move_mode is set to WALK.
@export var move_speed: float = 100.0

var last_known_position: Vector2 # For editor updates

func _ready() -> void:
	if Engine.is_editor_hint():
		last_known_position = global_position

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return

	if global_position != last_known_position:
		last_known_position = global_position
		
		# trigger the redraws for this node and its previous sibling.
		queue_redraw()
		if get_parent() and get_index() > 0:
			var previous_sibling = get_parent().get_child(get_index() - 1)
			if previous_sibling is Node2D:
				previous_sibling.queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint(): 
		return
	
	var parent = get_parent()
	if not parent: 
		return

	var own_index = get_index()
	if own_index < parent.get_child_count() - 1:
		var next_node = parent.get_child(own_index + 1)
		if next_node is Node2D:
			draw_line(Vector2.ZERO, to_local(next_node.global_position), Color.YELLOW, 2.0)

func execute(target: Node2D) -> void:
	match move_mode:
		MoveMode.WALK:
			await _walk_to_position(target)
		MoveMode.TELEPORT:
			target.global_position = global_position
	
	# After movement is done, call the specific action for the child node.
	_on_action(target)

func _on_action(target: Node2D) -> void:
	# Default behavior is to just complete immediately.
	emit_signal("completed")

func _walk_to_position(target: Node2D) -> void:
	var anim_player: AnimationPlayer = target.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var visuals: Node2D = target.get_node_or_null("Visuals") as Node2D
	var flip_node: Node2D = visuals if visuals != null else target
	#eps = epsilon, in this case it's a value that acts as a stop value, in pixels, for the actor when near target point
	var eps := 5.0
	var step := move_speed / float(Engine.get_physics_ticks_per_second())

	while target.global_position.distance_to(global_position) > eps:
		var dir := (global_position - target.global_position).normalized()
		target.global_position += dir * step

		if anim_player and anim_player.current_animation != "walk-loop":
			anim_player.play("walk-loop")

		if dir.x < -0.1:
			flip_node.scale.x = -abs(flip_node.scale.x)
		elif dir.x > 0.1:
			flip_node.scale.x = abs(flip_node.scale.x)

		await get_tree().physics_frame

	if anim_player:
		anim_player.play("idle-loop")
		anim_player.advance(0)
