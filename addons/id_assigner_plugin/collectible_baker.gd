# tools/collectibles/ccollectible_baker.gd
@tool
extends Node

# This helper function generates a random, unique ID string.
func _generate_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	var uuid_bytes = PackedByteArray()
	uuid_bytes.resize(16)
	for i in range(uuid_bytes.size()):
		uuid_bytes[i] = rng.randi_range(0, 255)
	return uuid_bytes.hex_encode()

# This is the core function our tool will call.
func assign_missing_collectible_ids():
	var scene = get_tree().edited_scene_root
	if not scene:
		print("ID Assigner: No scene is currently being edited.")
		return

	var collectibles = scene.find_children("*", "Collectible", true, false)
	if collectibles.is_empty():
		print("ID Assigner: No nodes with the 'Collectible' script found.")
		return

	var assigned_count = 0
	print("ID Assigner: Scanning for collectibles with missing IDs...")
	for collectible in collectibles:
		if not collectible is Collectible:
			continue

		if collectible.unique_id.is_empty():
			var new_id = _generate_uuid()
			collectible.set_unique_id(new_id)
			assigned_count += 1
			
			collectible.property_list_changed.emit()

			print("  - Assigned new ID '%s' to node: %s" % [new_id, collectible.name])

	if assigned_count > 0:
		print("ID Assigner: Complete! %d new IDs were assigned. Remember to save the scene (Ctrl+S)." % assigned_count)
	else:
		print("ID Assigner: No collectibles with missing IDs were found.")
