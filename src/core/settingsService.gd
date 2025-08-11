@tool

extends Node

const DEFAULT_CONFIG_FILE_NAME = "res://tools/services/settings/defaults.cfg"
var PLAYER_CONFIG_FILE_NAME = OS.get_data_dir() + "/Potato-Proto/settings.cfg"
var configFile = ConfigFile.new()

func initializeSettings():
	print(PLAYER_CONFIG_FILE_NAME)
	
	if !FileAccess.file_exists(PLAYER_CONFIG_FILE_NAME):
		initializeConfigFile()
	

func initializeConfigFile():
	#IMPORTANT
	#FOR THIS TO WORK YOU NEED TO CREATE THE FOLDER NOTED IN OS.get_data_dir()
	#IT WILL PRINT TO CONSOLE ON LAUNCH
	#WE SHOULD DO THIS AS PART OF AN INSTALLER LATER
	var newConfigFile = FileAccess.open(PLAYER_CONFIG_FILE_NAME, FileAccess.WRITE)
	var defaultsFile = FileAccess.open(DEFAULT_CONFIG_FILE_NAME, FileAccess.READ)
	var content = defaultsFile.get_as_text()
	newConfigFile.store_string(str(content))
	newConfigFile.close()
	defaultsFile.close()

func setSettingValue(setting: String, value: Variant) -> bool:

	var settingArray = setting.split('.')
	var section = settingArray[0]
	var key = settingArray[1]
	
	var err = configFile.load(PLAYER_CONFIG_FILE_NAME)
	if(err):
		print("Failed to set ", section, ".", key, " to ", value)
		print(err)
		return false
		
	configFile.set_value(section, key, value)

	setSpecialSettings(section, key, value)

	# Save it to a file (overwrite if already exists).
	return configFile.save(PLAYER_CONFIG_FILE_NAME)

func setSpecialSettings(section: String, key: String, value: Variant) -> void:
	match section:
		"audio":
			AudioService.set(key, value)

func getSettingValue(setting: String) -> Variant:
	var settingArray = setting.split('.')
	var section = settingArray[0]
	var key = settingArray[1]
	
	var err = configFile.load(PLAYER_CONFIG_FILE_NAME)

	# If the file didn't load, ignore it.
	if err != OK:
		print("Error opening config file")
		print(err)
		return err

	# Fetch the data for each section.
	return configFile.get_value(section, key)
	
