@tool

extends Node

var PLAYER_CONFIG_FILE_NAME = OS.get_data_dir() + "/Potato Game/settings.cfg"
var configFile = ConfigFile.new()

const SECTION_META := "meta"
const KEY_SCHEMA := "schema_version"
const CURRENT_SCHEMA := 1 # bump when you change layout/types

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var err := configFile.load(PLAYER_CONFIG_FILE_NAME)
	if err != OK:
		# Start fresh if file missing/corrupt; still run migrations to apply defaults.
		print("No existing settings file, creating new one")
		configFile.set_value(SECTION_META, KEY_SCHEMA, 0)

	var schema := int(configFile.get_value(SECTION_META, KEY_SCHEMA, 0))
	if schema <= CURRENT_SCHEMA:
		print("Executing migrations...")
		_migrate(schema)
		_safe_save()
		print("Done!")

func _migrate(from_schema: int) -> void:
	var v := from_schema
	while v <= CURRENT_SCHEMA:
		print("Executing migration " + str(v))
		match v:
			0:
				#0 → 1: introduce audio + display setting sections with default values
				_ensure_section_defaults("audio", {
					"master_volume": 100,
					"music_volume":  80,
					"sfx_volume":    80,
				})
				
				_ensure_section_defaults("display", {
					"display_mode": 0,
					"display_resolution": Vector2i(1280, 720)
				})
			1:
				_ensure_section_defaults("player", {
					"name": "Potato"
				})
			_:
				push_warning("Unknown migration step from %d" % v)
				break

			#Further examples of how to update settings
			#1:
				## → 2: type change example: volumes were int 0..100 → float 0..1
				#for key in ["master_volume", "music_volume", "sfx_volume"]:
					#var old_val = configFile.get_value("audio", key, 100)
					#if typeof(old_val) == TYPE_INT:
						#configFile.set_value("audio", key, clamp(float(old_val) / 100.0, 0.0, 1.0))
			#2:
				## → 3: add a new gameplay setting with default, keep existing values
				#_ensure_section_defaults("gameplay", {
					#"auto_pause_on_focus_loss": true,
				#})

		#Increment version, run next migration
		v+=1

	setSettingValue(SECTION_META, KEY_SCHEMA, CURRENT_SCHEMA)

#Given a section, ensure that default settings are set. Will not overwrite existing setting values if present
func _ensure_section_defaults(section: String, defaults: Dictionary) -> void:
	for k in defaults.keys():
		if not configFile.has_section_key(section, k):
			configFile.set_value(section, k, defaults[k])

func _safe_save() -> void:
	# Atomic-ish save: write to temp, then replace
	var tmp := "%s.tmp" % PLAYER_CONFIG_FILE_NAME
	var backup := "%s.bak" % PLAYER_CONFIG_FILE_NAME

	var err := configFile.save(tmp)
	if err != OK:
		push_error("Failed to write temp settings: %s" % err)
		return

	# Make a backup of the last good file (optional but nice)
	if FileAccess.file_exists(PLAYER_CONFIG_FILE_NAME):
		DirAccess.remove_absolute(backup)
		DirAccess.copy_absolute(PLAYER_CONFIG_FILE_NAME, backup)

	# Replace original with temp
	DirAccess.remove_absolute(PLAYER_CONFIG_FILE_NAME)
	DirAccess.rename_absolute(tmp, PLAYER_CONFIG_FILE_NAME)

#This doesn't work how it should right now, don't use it yet
func setAllSettingsToDefault() -> void:
	#Delete the settings file and run migrate again
	pass

func setSettingValue(section: String, key: String, value: Variant) -> bool:
	configFile.set_value(section, key, value)
	setSpecialSettings(section, key, value)
	_safe_save()

	# Save it to a file (overwrite if already exists).
	return configFile.save(PLAYER_CONFIG_FILE_NAME)

func setSpecialSettings(section: String, key: String, value: Variant) -> void:
	match section:
		"audio":
			AudioService.set(key, value)
		"display":
			DisplayManager.set(key, value)

func getSettingValue(section: String, key: String) -> Variant:
	return configFile.get_value(section, key)
