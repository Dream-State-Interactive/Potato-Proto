extends Node

@export var currentLeaderboard: Array
@export var minimum_highscore: int
@export var NUM_LEADERS_TO_SHOW: int = 10

signal leaderboard_updated

var DEFAULT_LEADERS: Array = [
	LeaderboardEntry.new("Jimmy Jones", 2500),
	LeaderboardEntry.new("Lil fry", 5000),
	LeaderboardEntry.new("Spuds Mackenzie", 10000),
	LeaderboardEntry.new("Tony Starch", 25000),
	LeaderboardEntry.new("Goobie", 50000),
	LeaderboardEntry.new("Old MacDundle", 100000)
]

const NUM_LEADERS_SAVED = 100 # Overkill, but overhead is minimal
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
	if(!FileAccess.file_exists(LEADERBOARD_FILE_PATH)):
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
		
		currentLeaderboard = []
		for entry in JSONObject:
			currentLeaderboard.append(LeaderboardEntry.new(entry["name"], entry["score"]))
	else:
		wipe_leaderboard()
		
	leaderboardFile.close()
	leaderboard_updated.emit()

func update_leaderboard(entry: LeaderboardEntry) -> void:
	currentLeaderboard.append(entry)
	currentLeaderboard.sort_custom(leaderboard_entry_sort_descending)
	currentLeaderboard = currentLeaderboard.slice(0, NUM_LEADERS_SAVED)
	var endOfArray = currentLeaderboard.size() - 1 if NUM_LEADERS_TO_SHOW - 1 > currentLeaderboard.size() - 1 else NUM_LEADERS_TO_SHOW - 1
	minimum_highscore = currentLeaderboard[endOfArray].score
	leaderboard_updated.emit()
	save_leaderboard()
		
func wipe_leaderboard() -> void:
	currentLeaderboard = DEFAULT_LEADERS
	currentLeaderboard.sort_custom(leaderboard_entry_sort_descending)
	leaderboard_updated.emit()
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
