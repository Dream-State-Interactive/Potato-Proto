@tool

extends Node2D

@onready var LeaderboardTextbox = $LeaderboardText

const NUM_LEADERS_SHOWN = 5

func _ready() -> void:
	refresh_leaderboard_text()
		
func refresh_leaderboard_text() -> void:
	LeaderboardTextbox.text = ""
	for i in range (NUM_LEADERS_SHOWN):
		LeaderboardTextbox.text += Leaderboard.currentLeaderboard[i].name + ": " + str(Leaderboard.currentLeaderboard[i].score) + "\n"
