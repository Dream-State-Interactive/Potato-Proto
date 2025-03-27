extends Node

var MasterBus = AudioServer.get_bus_index("Master")

func set_master_volume(volume: float):
	if(volume > 100):
		volume = 100
	elif (volume < 0):
		volume = 0
	
	volume /= 100
	
	AudioServer.set_bus_volume_db(MasterBus, linear_to_db(volume))

func get_master_volume() -> int:
	return db_to_linear(AudioServer.get_bus_volume_db(MasterBus))
