@tool

extends Node2D

@onready var LeaderboardTextbox = $LeaderboardText

const MAX_NUM_LEADERS_SHOWN = 8

func _ready() -> void:
	refresh_leaderboard_text()
		
func refresh_leaderboard_text() -> void:
	LeaderboardTextbox.text = ""
	var leaderboardSize = Leaderboard.currentLeaderboard.size() if MAX_NUM_LEADERS_SHOWN > Leaderboard.currentLeaderboard.size() else MAX_NUM_LEADERS_SHOWN
	for i in range(leaderboardSize):
		LeaderboardTextbox.text += Leaderboard.currentLeaderboard[i].name + ": " + str(Leaderboard.currentLeaderboard[i].score) + "\n"
