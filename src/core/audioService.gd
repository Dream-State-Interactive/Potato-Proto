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

		var sfxBus = AudioServer.get_bus_index("SFX")
		AudioServer.set_bus_volume_db(sfxBus, linear_to_db(volume))
	get:
		var sfxBus = AudioServer.get_bus_index("SFX")
		return db_to_linear(AudioServer.get_bus_volume_db(sfxBus))

func _ready():
	master_volume = SettingsService.getSettingValue("audio", "master_volume")
	music_volume = SettingsService.getSettingValue("audio", "music_volume")
	sfx_volume = SettingsService.getSettingValue("audio", "sfx_volume")
