# =============================================================================
# src/core/scene_loader.gd - A Safe Scene Transition Manager
# =============================================================================
#
# WHAT IT IS:
# A very simple but critical Autoload Singleton. Its ONLY job is to handle
# changing or reloading scenes.
#
# ARCHITECTURE:
# The core problem it solves is "dangling references". When you change a scene,
# old nodes are destroyed, but global singletons (like GameManager) might still
# hold references to them, which causes crashes. This loader ensures that we
# always clean up those old references BEFORE the scene change happens.
#
# All other scripts in the game should use `SceneLoader.change_scene()` instead
# of calling `get_tree().change_scene_to_file()` directly.
#
# =============================================================================
extends Node

# --- Constants ---
const MAIN_GAME_SCENE = "res://src/main.tscn"
const TRANSITION_SCENE = preload("res://src/ui/transitions/falling_potatoes.tscn")

# --- State Variables ---
var current_scene_path: String = ""
var target_scene_path: String = ""
var _is_changing: bool = false
var _transition_is_opaque: bool = false
var current_transition = null

signal scene_loaded

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Disable _process when we aren't loading to save performance
	set_process(false)

func _process(_delta):
	# 1. Check the status of the background load
	var status = ResourceLoader.load_threaded_get_status(target_scene_path)
	
	# 2. If the asset is fully loaded...
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if _transition_is_opaque:
			_finish_loading_and_switch()
			
	elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or status == ResourceLoader.THREAD_LOAD_FAILED:
		printerr("SceneLoader: Threaded load failed for path: ", target_scene_path)
		set_process(false)
		_is_changing = false

## Synchronous fallback for changing scenes (no transition).
func change_scene(scene_path: String):
	if scene_path.is_empty():
		printerr("SceneLoader: change_scene was called with an empty path! Aborting scene change.")
		return
	
	# Stop any threaded loading if it was happening
	_is_changing = false
	set_process(false)
	
	GameManager.prepare_for_scene_change()
	GameManager.current_level_path = scene_path
	current_scene_path = scene_path
	MenuManager.clear_history()
	AudioService.stop_all_looping()
	
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	scene_loaded.emit()
	GameManager.on_level_loaded()
	
	GameManager.resume()

## Non-blocking means of changing scenes with an effect
## https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html 
func change_scene_with_transition(scene_path: String) -> void:
	if _is_changing: 
		return
	if scene_path.is_empty():
		printerr("SceneLoader: change_scene_with_transition called with empty path.")
		return

	_is_changing = true
	target_scene_path = scene_path
	_transition_is_opaque = false

	# 1. Start the visual transition (Potatoes start falling)
	var transition := TRANSITION_SCENE.instantiate()
	current_transition = transition
	GUI.start_transition(transition)
	
	# 2. Request the background load on a separate thread
	ResourceLoader.load_threaded_request(scene_path)
	
	# 3. Start checking for completion every frame
	set_process(true)

## Called by the transition scene when the screen is fully black
func _on_transition_opaque() -> void:
	_transition_is_opaque = true

## Internal function to finalize the swap once Load + Fade are both done
func _finish_loading_and_switch():
	set_process(false)
	_is_changing = false
	
	# 1. Retrieve the loaded resource (It's instant now because it's in memory)
	var new_scene_resource = ResourceLoader.load_threaded_get(target_scene_path)
	
	# 2. Clean up old state
	GameManager.prepare_for_scene_change()
	GameManager.current_level_path = target_scene_path
	current_scene_path = target_scene_path
	MenuManager.clear_history()
	AudioService.stop_all_looping()
	
	# 3. Swap the scene
	get_tree().change_scene_to_packed(new_scene_resource)
	
	await get_tree().process_frame
	scene_loaded.emit()
	GameManager.on_level_loaded()
	GameManager.resume()
	
	# 4. Fade out
	if current_transition:
		current_transition.finish_transition()

## Restarts the current level
func reload_current_scene():
	if current_scene_path.is_empty():
		printerr("SceneLoader: Cannot restart level, no level path is stored.")
		return
		
	print("Restarting level: ", current_scene_path)
	GameManager.reset_game_state()
	change_scene_with_transition(current_scene_path)

## Restarts the Main scene itself
func hard_reset_game():
	MenuManager.clear_history()
	print("SceneLoader: Reloading current scene.")
	GameManager.prepare_for_scene_change()
	
	# We use the standard reload here as a failsafe
	get_tree().reload_current_scene()
	GameManager.resume()
