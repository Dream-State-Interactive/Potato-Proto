# src/components/sequencer/conditions/condition_player_in_area.gd
extends Condition
class_name ConditionPlayerInArea

## The path to the Area2D node in the scene that we want to check.
@export var area_path: NodePath

# This is the function the ConditionalBranchNode will call every frame.
func check(actor: Node2D) -> bool:
	# First, try to get the Area2D node from the path.
	var area = actor.get_node_or_null(area_path)
	if not area is Area2D:
		# If the path is wrong or the node isn't an Area2D, the condition is false.
		push_warning("ConditionPlayerInArea: Path does not point to a valid Area2D.")
		return false

	# Next, get a list of all nodes currently in the "player" group.
	var players_in_scene = actor.get_tree().get_nodes_in_group("player")
	if players_in_scene.is_empty():
		# If there's no player in the scene, the condition is false.
		return false
	
	# We assume the first node in the group is our player.
	var player_body = players_in_scene[0]

	# Area2D has a built-in list of all physics bodies it's currently overlapping.
	# We check if our player's body is in that list.
	for body in area.get_overlapping_bodies():
		if body == player_body:
			# Found the player inside the area! The condition is true.
			return true
	
	# If the loop finishes without finding the player, the condition is false.
	return false
