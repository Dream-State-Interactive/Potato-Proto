@tool

extends Node2D

@onready var LeaderboardTextbox = $LeaderboardText

var NUM_LEADERS_TO_SHOW = Leaderboard.NUM_LEADERS_TO_SHOW

func _ready() -> void:
	refresh_leaderboard_text()
	Leaderboard.leaderboard_updated.connect(refresh_leaderboard_text)
		
func refresh_leaderboard_text():
	LeaderboardTextbox.text = ""
	var leaderboardSize = Leaderboard.currentLeaderboard.size() if NUM_LEADERS_TO_SHOW > Leaderboard.currentLeaderboard.size() else NUM_LEADERS_TO_SHOW
	for i in range(leaderboardSize):
		LeaderboardTextbox.text += Leaderboard.currentLeaderboard[i].name + ": " + str(Leaderboard.currentLeaderboard[i].score) + "\n"
