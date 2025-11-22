extends Node

var MasterBus = AudioServer.get_bus_index("Master")

@export var master_volume: float:
	set(volume):
		if(volume > 100):
			volume = 100
		elif (volume < 0):
			volume = 0
		
		volume /= 100
	
		AudioServer.set_bus_volume_db(MasterBus, linear_to_db(volume))
	get:
		return db_to_linear(AudioServer.get_bus_volume_db(MasterBus))

@export var music_volume: float:
	set(volume):
		if(volume > 100):
			volume = 100
		elif (volume < 0):
			volume = 0
		
		volume /= 100
	
		var musicBus = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(musicBus, linear_to_db(volume))
	get:
		var musicBus = AudioServer.get_bus_index("Music")
		return db_to_linear(AudioServer.get_bus_volume_db(musicBus))

@export var sfx_volume: float:
	set(volume):
		if(volume > 100):
			volume = 100
		elif (volume < 0):
			volume = 0

		volume /= 100

		var sfxBus = AudioServer.get_bus_index("Effects")
		AudioServer.set_bus_volume_db(sfxBus, linear_to_db(volume))
	get:
		var sfxBus = AudioServer.get_bus_index("Effects")
		return db_to_linear(AudioServer.get_bus_volume_db(sfxBus))

# TODO: wire up loop functionality to this
func play_music(stream: AudioStream, volume_db: float = 0.0, position: Vector2 = Vector2.ZERO) -> void:
	play_sound(stream, "Music", 0, volume_db, position)

func play_sfx(stream: AudioStream, pitch_range: float = 1.0, volume_db: float = 0.0, position: Vector2 = Vector2.ZERO) -> void:
	play_sound(stream, "Effects", pitch_range, volume_db, position)

func play_sound(stream: AudioStream, bus: String = "Effects", pitch_range: float = 0, volume_db: float = 0.0, position: Vector2 = Vector2.ZERO) -> void:
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	audio_player.volume_db = volume_db
	audio_player.bus = bus
	audio_player.position = position
	get_tree().root.add_child(audio_player)
	audio_player.play()
	audio_player.connect("finished", Callable(audio_player, "queue_free"))

func _ready():
	master_volume = SettingsService.getSettingValue("audio", "master_volume")
	music_volume = SettingsService.getSettingValue("audio", "music_volume")
	sfx_volume = SettingsService.getSettingValue("audio", "sfx_volume")
