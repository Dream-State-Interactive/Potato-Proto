extends Node

var MasterBus := AudioServer.get_bus_index("Master")

# key -> AudioStreamPlayer2D
var _looping_players: Dictionary = {}

@export var master_volume: float:
	set(volume):
		if volume > 100:
			volume = 100
		elif volume < 0:
			volume = 0

		volume /= 100.0
		AudioServer.set_bus_volume_db(MasterBus, linear_to_db(volume))
	get:
		return db_to_linear(AudioServer.get_bus_volume_db(MasterBus))

@export var music_volume: float:
	set(volume):
		if volume > 100:
			volume = 100
		elif volume < 0:
			volume = 0

		volume /= 100.0

		var music_bus := AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(volume))
	get:
		var music_bus := AudioServer.get_bus_index("Music")
		return db_to_linear(AudioServer.get_bus_volume_db(music_bus))

@export var sfx_volume: float:
	set(volume):
		if volume > 100:
			volume = 100
		elif volume < 0:
			volume = 0

		volume /= 100.0

		var sfx_bus := AudioServer.get_bus_index("Effects")
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(volume))
	get:
		var sfx_bus := AudioServer.get_bus_index("Effects")
		return db_to_linear(AudioServer.get_bus_volume_db(sfx_bus))

# Music: usually one looping track at a time.
# `key` lets you control/stop this music later (defaults to "music").
func play_music(stream: AudioStream, volume_db: float = 1.0, position: Vector2 = Vector2.ZERO, loop: bool = true, key: StringName = &"music") -> void:
	# Stop any existing music with the same key.
	stop_sound(key)
	_play_sound(stream, "Music", 0.0, volume_db, position, loop, key)

func stop_music(key: StringName = &"music") -> void:
	stop_sound(key)

# SFX: one-shots by default (auto-freed).
# If you pass loop = true AND a key, the SFX is tracked and can be stopped.
func play_sfx(stream: AudioStream, pitch_range: float = 1.0, volume_db: float = 0.0, position: Vector2 = Vector2.ZERO, loop: bool = false, key: StringName = StringName()) -> void:
	_play_sound(stream, "Effects", pitch_range, volume_db, position, loop, key)

func stop_sound(key: StringName) -> void:
	if not _looping_players.has(key):
		return

	var player = _looping_players[key]
	if is_instance_valid(player):
		player.stop()
		player.queue_free()

	_looping_players.erase(key)

func stop_all_looping(fade_time: float = 0.75) -> void:
	for key in _looping_players.keys():
		var player: AudioStreamPlayer2D = _looping_players[key]
		if not is_instance_valid(player):
			continue

		var tween := create_tween()
		# Fade volume_db to -80 dB (effectively silence)
		tween.tween_property(player, "volume_db", -80.0, fade_time)
		# When tween finishes, clean up this player
		tween.tween_callback(Callable(self, "stop_sound").bind(key))


func _play_sound(stream: AudioStream, bus: String = "Effects", pitch_range: float = 0.0, volume_db: float = 0.0, position: Vector2 = Vector2.ZERO, loop: bool = false, key: StringName = StringName()) -> void:
	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	audio_player.volume_db = volume_db
	audio_player.bus = bus
	audio_player.position = position

	# Only force loop on when requested.
	# (If you want to force it off when loop == false, you can also set .loop = false here.)
	if "loop" in audio_player.stream:
		audio_player.stream.loop = loop

	get_tree().root.add_child(audio_player)

	if loop and key != StringName():
		# Track this looping sound so we can stop it later.
		if _looping_players.has(key):
			stop_sound(key)
		_looping_players[key] = audio_player
	elif not loop:
		# One-shot: auto free when finished.
		audio_player.connect("finished", func():
			audio_player.queue_free()
		)

	audio_player.play()

func _ready() -> void:
	master_volume = SettingsService.getSettingValue("audio", "master_volume")
	music_volume = SettingsService.getSettingValue("audio", "music_volume")
	sfx_volume = SettingsService.getSettingValue("audio", "sfx_volume")
