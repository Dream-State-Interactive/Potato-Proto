@tool

extends Node2D

@onready var LeaderboardTextbox = $LeaderboardText

const DEFAULT_LEADERS: Dictionary = { "Spuds": 500, "Lil fry": 475, "Tony Starch": 420 }

func _ready() -> void:
	LeaderboardTextbox.text = ""
	var leaderboard = assemble_leaderboard()
	for key in leaderboard.keys():
		LeaderboardTextbox.text = LeaderboardTextbox.text + key + ": " + str(DEFAULT_LEADERS[key]) + "\n"

func assemble_leaderboard() -> Dictionary:
	return DEFAULT_LEADERS
