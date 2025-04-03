@tool

extends Node

var configFileName = OS.get_data_dir() + "/Potato-Proto/settings.cfg"
var configFile = ConfigFile.new()

func initializeSettings():
	checkConfigFile()
	print(configFileName)
	print('Master volume:')
	print(SettingsService._get("master_volume"))
	AudioService.set_master_volume(SettingsService.get("master_volume"))
	
func save_file(data):
	var file = FileAccess.open("user://Data.dat", FileAccess.WRITE)
	file.store_string(str(data))
	file.close()

func checkConfigFile():
	if !FileAccess.file_exists(configFileName):
		save_file(configFileName)
	else:
		var file = FileAccess.open("user://OceanLifeData.dat", FileAccess.READ)
		file.close()

func _set(setting: StringName, value: Variant) -> bool:
	var err = configFile.load(configFileName)
	if(err):
		print(err)
		return false
	# Store some values.
	configFile.set_value(setting, setting, value.toString())

	# Save it to a file (overwrite if already exists).
	return configFile.save(configFileName)

func _get(key: StringName) -> Variant:
	var err = configFile.load(configFileName)

	# If the file didn't load, ignore it.
	if err != OK:
		return err

	# Fetch the data for each section.
	return configFile.get_value("Settings", key)
