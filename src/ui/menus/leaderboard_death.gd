extends Node2D

var highscore_submitted = false
@onready var nameInput = $NameLineEntry
@onready var submitHighScoreButton = $SubmitHighscoreButton
var score = GameManager.last_player_score

func _ready():
	if score < Leaderboard.minimum_highscore:
		submitHighScoreButton.visible = false
		nameInput.visible = false
	nameInput.placeholder_text = SettingsService.getSettingValue("player", "name")

func submit_highscore():
	if(!highscore_submitted):
		highscore_submitted = true
		Leaderboard.update_leaderboard(Leaderboard.LeaderboardEntry.new(SettingsService.getSettingValue("player", "name"), score))

func _on_restart_button_pressed() -> void:
	_on_submit_highscore_button_pressed()

func _on_submit_highscore_button_pressed() -> void:
	if(nameInput.text != ""):
		SettingsService.setSettingValue("player", "name", nameInput.text)
	submit_highscore()
