# src/collectibles/collectible.gd
@tool
class_name Collectible
extends Area2D

## This ID is automatically generated and "baked" into the scene file by our editor tool.
## Do not change it manually (or just make sure it's unique at least).
@export var unique_id: String = "":
	set(value):
		if unique_id == value:
			return
		unique_id = value
		# If we are in the editor, we MUST notify that a property has changed.
		if Engine.is_editor_hint():
			property_list_changed.emit()
	get:
		return unique_id

func _ready():
	# Run only when the game is playing.
	if not Engine.is_editor_hint():
		if GameManager.is_item_collected(unique_id):
			queue_free()

func _on_collect(player: Player):
	push_warning("The _on_collect() method must be implemented in a child collectinle")


func _on_triggered(body):
	if body is Player:
		# 1. First, register this item's ID as collected with the GameManager.
		GameManager.register_collected_item(unique_id)
		
		# 2. Then, execute the specific collection behavior (give starch, health, etc.).
		_on_collect(body)
		
		# 3. Finally, remove the item from the scene.
		queue_free()


## Modify the exported variable via our (OBSOLETE) tool script
func set_unique_id(id: String):
	unique_id = id
