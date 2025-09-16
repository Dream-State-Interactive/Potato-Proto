# src/components/sequencer/nodes/action/node_interact.gd
# A sequence action that makes the target play a specific animation.

@tool
extends SequenceNode
class_name InteractNode

@export var animation_name: StringName
@export var completion_delay: float = 0.0

func _on_action(target: Node2D) -> void:
	var anim_player = target.get_node_or_null("AnimationPlayer")
	if not anim_player or not anim_player.has_animation(animation_name):
		emit_signal("completed")
		return

	anim_player.play(animation_name)

	if completion_delay > 0:
		await get_tree().create_timer(completion_delay).timeout
	else:
		await anim_player.animation_finished
		
	emit_signal("completed")
