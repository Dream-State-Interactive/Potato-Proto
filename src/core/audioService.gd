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

func _ready():
	master_volume = SettingsService.getSettingValue("audio.master_volume")
