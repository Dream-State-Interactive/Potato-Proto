@tool

extends Node

var configFileName = "user://scores.cfg"
var configFile = ConfigFile.new()

func _set(setting: StringName, value: Variant) -> bool:
	var config = ConfigFile.new()
	var err = config.load(configFileName)
	if(err):
		return false
	# Store some values.
	config.set_value(setting, setting, value.toString())

	# Save it to a file (overwrite if already exists).
	return config.save("user://scores.cfg")

func _get(key: StringName) -> Variant:
	var score_data = {}
	var err = configFile.load(configFileName)

	# If the file didn't load, ignore it.
	if err != OK:
		return err

	# Fetch the data for each section.
	return configFile.get_value("Settings", key) 
