# src/dialogue/dialogue_player.gd
extends Node
class_name DialoguePlayer

signal dialogue_finished

@export var dialogue: DialogueResource
@export var bubble_scene: PackedScene
@export var ui_layer_path: NodePath
@export var actors: Dictionary

var _bubble: SpeechBubble = null
var _current_line_index = 0
var _is_playing = false
var _current_actor: Node2D = null


func _ready():
	set_process(true)
	print("Current game locale at start: ", TranslationServer.get_locale())

func _process(delta):
	if _is_playing and is_instance_valid(_current_actor) and is_instance_valid(_bubble):
		var screen_position = get_viewport().get_canvas_transform() * _current_actor.global_position
		var bubble_size := _bubble.size
		_bubble.global_position = screen_position + Vector2(-bubble_size.x * 0.5, -bubble_size.y - 40)

func play() -> void:
	if _is_playing or not dialogue:
		print("NOTHING SIR")
		return

	var ui_layer := get_node_or_null(ui_layer_path)
	if ui_layer == null:
		push_warning("DialoguePlayer: ui_layer_path invalid or UI layer not found: %s" % [ui_layer_path])
		return

	_is_playing = true
	_current_line_index = 0

	if not is_instance_valid(_bubble):
		print("SHIT AINT VALID, VALIDATING...")
		_bubble = bubble_scene.instantiate()
		ui_layer.add_child(_bubble)

		if not _bubble.is_node_ready():
			_bubble.ready.connect(_on_bubble_ready, CONNECT_ONE_SHOT)
			return

	_start_dialogue()

func _on_bubble_ready() -> void:
	if not _is_playing:
		return
	_start_dialogue()

func _start_dialogue() -> void:
	print("OH WE GO BABY")
	_show_current_line()



func _unhandled_input(event):
	if _is_playing and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_bubble.advance()

func _show_current_line():
	_current_actor = null
	if _current_line_index >= dialogue.lines.size():
		_stop()
		return

	var line = dialogue.lines[_current_line_index]
	var actor_node = get_node_or_null(actors.get(line.speaker_key))

	if not actor_node or not actor_node is Node2D:
		push_warning("DialoguePlayer: Actor for key '%s' not found or not a Node2D. Skipping line." % line.speaker_key)
		_current_line_index += 1
		_show_current_line()
		return
	
	_current_actor = actor_node
	
	var key_to_translate = line.text_key
	print("Attempting to translate key: '", key_to_translate, "'")
	var key: String = String(line.text_key)
	var translated: String = tr(key)

	# If no translation exists, returns the key unchanged.
	var final_text: String = translated if translated != key else key
	print("Translation result: '", final_text, "'")
	
	#var final_text = tr(line.text_key)
	_bubble.show_text(final_text)
	
	await get_tree().process_frame
	_process(0.0)

	_bubble.finished.connect(_on_bubble_finished, CONNECT_ONE_SHOT)

func _on_bubble_finished():
	_current_line_index += 1
	_show_current_line()

func _stop():
	_is_playing = false
	dialogue_finished.emit()
