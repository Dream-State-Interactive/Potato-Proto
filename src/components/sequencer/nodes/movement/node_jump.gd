# src/components/sequencer/nodes/movement/node_jump.gd
@tool
extends SequenceNode
class_name JumpNode

@export var landing_point_path: NodePath
@export var jump_height: float = 100.0:
	set(new_value):
		if jump_height == new_value:
			return
		
		jump_height = new_value
		
		if Engine.is_editor_hint():
			if is_inside_tree() and is_node_ready():
				queue_redraw()
@export var duration: float = 1.0
@export var jump_start_animation: StringName
@export var jump_loop_animation: StringName
@export var jump_end_animation: StringName

var last_landing_point_pos: Vector2

func _process(_delta: float) -> void:
	super._process(_delta)
	if not Engine.is_editor_hint():
		return

	var landing_node = get_node_or_null(landing_point_path)
	if landing_node is Node2D:
		if landing_node.global_position != last_landing_point_pos:
			last_landing_point_pos = landing_node.global_position
			queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var landing_node = get_node_or_null(landing_point_path)

	# Part 1: Draw the blue jump curve (from self to landing point)
	if landing_node is Node2D:
		var start_point = Vector2.ZERO
		var end_point = to_local(landing_node.global_position)
		var control_point = (start_point + end_point) / 2 + Vector2(0, -jump_height)
		var curve_points: PackedVector2Array = []
		for i in range(21): 
			var t = i / 20.0
			var point = start_point.lerp(control_point, t).lerp(control_point.lerp(end_point, t), t)
			curve_points.append(point)
		draw_polyline(curve_points, Color.SKY_BLUE, 2.0)

	# Part 2: Draw the yellow connecting line (from landing point to next node)
	var parent = get_parent()
	if not parent:
		return

	var own_index = get_index()
	if own_index < parent.get_child_count() - 1:
		var next_node = parent.get_child(own_index + 1)
		if next_node is Node2D:
			# THE FIX: The line starts from the landing_node's position,
			# or falls back to this node's origin if the landing point isn't set.
			var line_start_pos = global_position
			if landing_node is Node2D:
				line_start_pos = landing_node.global_position
			
			# Convert both points to local space for drawing.
			var start_local = to_local(line_start_pos)
			var end_local = to_local(next_node.global_position)
			draw_line(start_local, end_local, Color.YELLOW, 2.0)

func _on_action(target: Node2D) -> void:
	var landing_node = get_node_or_null(landing_point_path)
	if not landing_node is Node2D:
		push_warning("JumpNode: Landing point not set or invalid. Skipping.")
		emit_signal("completed")
		return

	var anim_player = target.get_node_or_null("AnimationPlayer")
	
	# 1. Play the start animation and wait for it to finish.
	if anim_player and anim_player.has_animation(jump_start_animation):
		anim_player.play(jump_start_animation)
		await anim_player.animation_finished

	# 2. Play the looping animation (don't wait for it).
	if anim_player and anim_player.has_animation(jump_loop_animation):
		anim_player.play(jump_loop_animation)

	# 3. Create and run the movement tween.
	var tween = create_tween()
	var start_pos = target.global_position
	var end_pos = landing_node.global_position
	var control_pos = (start_pos + end_pos) / 2 + Vector2(0, -jump_height)
	
	tween.tween_method(
		func(t): target.global_position = start_pos.lerp(control_pos, t).lerp(control_pos.lerp(end_pos, t), t),
		0.0, 1.0, duration
	)

	# 4. Wait for the TWEEN to finish (not the looping animation).
	await tween.finished

	# 5. Play the end animation and wait for it to finish.
	if anim_player and anim_player.has_animation(jump_end_animation):
		anim_player.play(jump_end_animation)
		await anim_player.animation_finished

	# 6. Complete the node.
	emit_signal("completed")
