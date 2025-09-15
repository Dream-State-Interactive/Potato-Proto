# src/components/sequencer/nodes/timing/node_wait.gd
@tool
extends SequenceNode
class_name WaitNode

@export var wait_time: float = 1.0
@export var animation_name: StringName = "idle-loop"

# Renamed execute to _on_action
func _on_action(target: Node2D) -> void:
	if not animation_name.is_empty():
		var anim_player = target.get_node_or_null("AnimationPlayer")
		if anim_player and anim_player.has_animation(animation_name):
			anim_player.play(animation_name)
			anim_player.advance(0)
	
	await get_tree().create_timer(wait_time).timeout
	emit_signal("completed")
