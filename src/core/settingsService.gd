@tool

extends Node

const DEFAULT_CONFIG_FILE_NAME = "res://src/core/defaults.cfg"
var PLAYER_CONFIG_FILE_NAME = OS.get_data_dir() + "/Potato Game/settings.cfg"
var configFile = ConfigFile.new()

func _ready() -> void:	
	if !FileAccess.file_exists(PLAYER_CONFIG_FILE_NAME):
		print(PLAYER_CONFIG_FILE_NAME + " does not exist. Creating file...")
		await initializeConfigFile()
	var err = configFile.load(PLAYER_CONFIG_FILE_NAME)
	if err:
		print("Error: Config file failed to load")
		print(err)

func initializeConfigFile():
	var newConfigFile = FileAccess.open(PLAYER_CONFIG_FILE_NAME, FileAccess.WRITE)
	var defaultsFile = FileAccess.open(DEFAULT_CONFIG_FILE_NAME, FileAccess.READ)
	var content = defaultsFile.get_as_text()
	newConfigFile.store_string(content)
	newConfigFile.close()
	defaultsFile.close()
	print("Config file initialized")

func setAllSettingsToDefault() -> void:
	var defaultsConfigObject = ConfigFile.new()
	var err = defaultsConfigObject.load(DEFAULT_CONFIG_FILE_NAME)
	if err:
		print("Error: Default config file failed to load")
		print(err)
		return
	for section in defaultsConfigObject.get_sections():
		for key in defaultsConfigObject.get_section_keys(section):
			var defaultSettingValue = defaultsConfigObject.get_value(section, key)
			print("Setting " + section + "." + key + " to ")
			print(defaultSettingValue)
			setSettingValue(section + "." + key, defaultSettingValue)

func setSettingValue(setting: String, value: Variant) -> bool:
	var settingArray = setting.split('.')
	var section = settingArray[0]
	var key = settingArray[1]
	
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

	# Fetch the data for each section.
	return configFile.get_value(section, key)
	
