# =============================================================================
# scene_loader.gd - A Safe Scene Transition Manager
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

const MAIN_GAME_SCENE = "res://src/main.tscn"
const TRANSITION_SCENE = preload("res://src/ui/transitions/falling_potatoes.tscn")

var current_scene_path: String = ""
var target_scene_path: String = ""
var _is_changing: bool = false
var current_transition = null

signal scene_loaded

## This is now the one and only safe way to change to a new scene.
func change_scene(scene_path: String):
	if scene_path.is_empty():
		printerr("SceneLoader: change_scene was called with an empty path! Aborting scene change.")
		return
	
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
	
func change_scene_with_transition(scene_path: String) -> void:
	if _is_changing:
		return
	_is_changing = true

	self.target_scene_path = scene_path

	var transition := TRANSITION_SCENE.instantiate()
	current_transition = transition
	GUI.start_transition(transition)

func _on_transition_opaque() -> void:
	await change_scene(target_scene_path)
	current_transition.finish_transition()
	
	_is_changing = false


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
	get_tree().reload_current_scene()
	GameManager.resume()
