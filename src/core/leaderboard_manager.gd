extends Node

@export var currentLeaderboard: Array

var DEFAULT_LEADERS: Array = [
	LeaderboardEntry.new("Spuds", 50),
	LeaderboardEntry.new("Lil fry", 4075),
	LeaderboardEntry.new("Tony Starch", 420),
	LeaderboardEntry.new("Jinko Jones", 123),
	LeaderboardEntry.new("Tony Baloney", 444444)
]

const NUM_LEADERS_SAVED = 100 # Overkill, but this is super minimal data
var LEADERBOARD_FILE_PATH = OS.get_data_dir() + "/Potato Game/leaderboard.json"


class LeaderboardEntry:
	var name: String = ""
	var score: int = 0
	
	func _init(initName, initScore):
		name = initName
		score = initScore
		
	func to_dict() -> Dictionary:
		return {
			"name": name,
			"score": score
		}
		
func leaderboard_entry_sort_descending(a: LeaderboardEntry, b: LeaderboardEntry) -> bool:
	return a.score > b.score


func _ready() -> void:
	initialize_leaderboard_file()
	load_leaderboard()

func initialize_leaderboard_file() -> void:
	if(FileAccess.file_exists(LEADERBOARD_FILE_PATH)):
		var newLeaderboardFile = FileAccess.open(LEADERBOARD_FILE_PATH, FileAccess.WRITE_READ)
		newLeaderboardFile.close()
		wipe_leaderboard()

func load_leaderboard() -> void:
	var leaderboardFile = FileAccess.open(LEADERBOARD_FILE_PATH, FileAccess.READ)
	if(leaderboardFile == null):
		print("Error opening leaderboard file")

	var content = leaderboardFile.get_as_text()
	if(content != ""):
		var JSONObject = JSON.parse_string(content)
		if(JSONObject == null):
			wipe_leaderboard()
			return
		
		for entry in JSONObject:
			currentLeaderboard.append(LeaderboardEntry.new(entry["name"], entry["score"]))
	else:
		wipe_leaderboard()
		
	leaderboardFile.close()

func update_leaderboard(entry: LeaderboardEntry) -> void:
	currentLeaderboard.append(entry)
	currentLeaderboard.sort_custom(leaderboard_entry_sort_descending)
	currentLeaderboard = currentLeaderboard.slice(0, NUM_LEADERS_SAVED)
	save_leaderboard()
		
func wipe_leaderboard() -> void:
	currentLeaderboard = DEFAULT_LEADERS
	currentLeaderboard.sort_custom(leaderboard_entry_sort_descending)
	save_leaderboard()

func save_leaderboard() -> void:
	var leaderboardFile = FileAccess.open(LEADERBOARD_FILE_PATH, FileAccess.WRITE)
	
	# LeaderboardEntry class is custom, so it doesn't work as expected with JSON.stringify()
	# Gotta convert the data first
	var leaderboardStringifyObject: Array
	for entry in currentLeaderboard:
		leaderboardStringifyObject.append(entry.to_dict())
		
	leaderboardFile.store_string(JSON.stringify(leaderboardStringifyObject, '\t'))
	leaderboardFile.close()
