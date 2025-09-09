# =============================================================================
# save_manager.gd - Handles Saving and Loading Game Data
# =============================================================================
#
# WHAT IT IS:
# This is an Autoload Singleton dedicated to one job: writing game state to a
# file and reading it back. It interacts with the GameManager to get the data
# it needs to save.
#
# ARCHITECTURE:
# - It saves data in JSON format, which is human-readable and great for debugging.
# - It supports multiple save slots by generating different filenames.
# - It robustly handles data type conversion (e.g., from JSON Dictionaries back
#   to Godot Vector2 objects) to prevent crashes on load.
# - It clearly defines which stats are saved via the STATS_TO_SAVE constant,
#   making it easy to add or remove saved variables in the future.
#
# =============================================================================
extends Node

# --- Constants ---
# Using user:// is the correct way to store save files, as it's a writable
# directory on all platforms (Windows, Linux, Mac, Android, etc.).
const SAVE_FILE_PREFIX = "user://savegame_"
const SAVE_FILE_SUFFIX = ".json"

## A list of all stats we want to save from the player's StatBlock.
## If you add a new stat to StatBlock.gd that needs to be saved, just add its
## string name to this array.
const STATS_TO_SAVE = [
	"grip", "bounce", "roll_speed", "armor",
	"jump_force", "horizontal_nudge", "max_health"
]

# --- Helper Functions ---
## A simple function to generate the full path for a given save slot.
func get_save_path(slot_number: int) -> String:
	return "%s%d%s" % [SAVE_FILE_PREFIX, slot_number, SAVE_FILE_SUFFIX]

## Checks if a save file for a given slot exists on the disk.
func save_file_exists(slot_number: int) -> bool:
	return FileAccess.file_exists(get_save_path(slot_number))

# --- Core Public API ---
## Saves the entire game state to a specific slot.
func save_game(slot_number: int):
	var player = GameManager.player_instance
	# We create a dictionary to act as a container for all our save data.
	# This keeps the JSON file organized.
	var save_data = {"player_stats": {}, "game_state": {}, "player_state": {}}
	
	var pos = player.global_position
	save_data["player_state"]["global_position"] = {"x": pos.x, "y": pos.y}
	var rot = player.rotation
	save_data["player_state"]["rotation"] = rot
	var lin_vel = player.linear_velocity
	save_data["player_state"]["linear_velocity"] = {"x": lin_vel.x, "y": lin_vel.y}
	var ang_vel = player.angular_velocity
	save_data["player_state"]["angular_velocity"] = ang_vel
	
	# --- 1. Save Player Stats ---
	var player_stats = GameManager.player_stats
	if player_stats:
		for stat_name in STATS_TO_SAVE:
			# Safely check if the property exists before trying to get it.
			if stat_name in player_stats:
				save_data["player_stats"][stat_name] = player_stats.get(stat_name)
	
	# --- 2. Save Global Game State ---
	save_data["game_state"]["collected_items"] = GameManager.collected_items.keys()
	save_data["game_state"]["starch_points"] = GameManager.current_starch_points
	save_data["game_state"]["current_level_path"] = GameManager.current_level_path

	# --- 3. Save Specific Player State ---
	if is_instance_valid(player):
		save_data["player_state"]["health"] = player.health_component.current_health
		# Save the array of peel decal UV coordinates.
		var peel_decals = []
		for point in player.damage_points:
			peel_decals.append({"x": point.x, "y": point.y})
		save_data["player_state"]["peel_decals"] = peel_decals
	
	# --- 4. Write to File ---
	var save_path = get_save_path(slot_number)
	var save_file = FileAccess.open(save_path, FileAccess.WRITE)
	# stringify() converts our Godot Dictionary into a text-based JSON string.
	# The "\t" argument makes it "pretty-print" with tabs, which is great for debugging.
	var json_string = JSON.stringify(save_data, "\t")
	save_file.store_string(json_string)
	print("Game saved to slot %d!" % slot_number)


## Loads the entire game state from a specific slot.
func load_game(slot_number: int):
	if not save_file_exists(slot_number): return
	var save_file = FileAccess.open(get_save_path(slot_number), FileAccess.READ)
	# parse_string() converts the text from the file back into a Godot Dictionary.
	var json_data = JSON.parse_string(save_file.get_as_text())
	if not json_data: return

	# --- 1. Load Player Stats ---
	var player_stats = GameManager.player_stats
	if player_stats and "player_stats" in json_data:
		var loaded_stats = json_data["player_stats"]
		for stat_name in loaded_stats:
			if stat_name in player_stats:
				player_stats.set(stat_name, loaded_stats[stat_name])
	
	# --- 2. Load Global Game State ---
	if "game_state" in json_data:
		GameManager.set_starch_points(json_data["game_state"].get("starch_points", 0))
		GameManager.collected_items.clear()
		var loaded_ids = json_data["game_state"].get("collected_items", [])
		for id in loaded_ids:
			GameManager.collected_items[id] = true
		
	# --- 3. Load Specific Player State ---
	var player = GameManager.player_instance
	if is_instance_valid(player) and "player_state" in json_data:
		var loaded_player_state = json_data["player_state"]
		var pos_dict = loaded_player_state.get("global_position")
		if pos_dict is Dictionary and "x" in pos_dict and "y" in pos_dict:
			player.global_position = Vector2(pos_dict.x, pos_dict.y)
			
		player.rotation = loaded_player_state.get("rotation", 0.0)
		
		var lin_vel_dict = loaded_player_state.get("linear_velocity")
		if lin_vel_dict is Dictionary and "x" in lin_vel_dict and "y" in lin_vel_dict:
			player.linear_velocity = Vector2(lin_vel_dict.x, lin_vel_dict.y)
			
		player.angular_velocity = loaded_player_state.get("angular_velocity", 0.0)
		# Ensure the health component's max_health is up-to-date with stats from GameManager.player_stats
		player.health_component.max_health = player_stats.max_health
		
		# Set health on the HealthComponent.
		player.health_component.current_health = loaded_player_state.get("health", player.stats.max_health)
		
		# --- Data Type Conversion for Peel Decals ---
		# JSON doesn't know what a Vector2 is, so it saves it as a dictionary.
		# We must manually convert it back.
		var loaded_peel_data = loaded_player_state.get("peel_decals", [])
		var converted_peel_points: PackedVector2Array = []
		for point_dict in loaded_peel_data:
			if point_dict is Dictionary and "x" in point_dict and "y" in point_dict:
				converted_peel_points.append(Vector2(point_dict.x, point_dict.y))
		player.damage_points = converted_peel_points
		# --- End Conversion ---
		

		
	print("Game loaded from slot %d!" % slot_number)

## Reads a save file and returns its contents as a Dictionary without applying it.
func get_save_data(slot_number: int) -> Dictionary:
	if not save_file_exists(slot_number):
		return {}
	
	var save_file = FileAccess.open(get_save_path(slot_number), FileAccess.READ)
	var json_data = JSON.parse_string(save_file.get_as_text())
	
	# Return the parsed data, or an empty dictionary if parsing failed.
	return json_data if json_data else {}
