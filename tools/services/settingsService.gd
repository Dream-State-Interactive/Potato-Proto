@tool

extends Node

var configFileName = "user://settings.cfg"
var configFile = ConfigFile.new()

func _set(setting: StringName, value: Variant) -> bool:
	var err = configFile.load(configFileName)
	if(err):
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
