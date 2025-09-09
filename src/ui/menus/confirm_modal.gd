extends Node2D
@onready var clearLeadersButton = $ClearLeadersButton
@onready var backButton = $BackButton


func _ready():
	GUI.show_pause_menu_backdrop()

func _on_clear_leaders_button_pressed() -> void:
	GUI.hide_pause_menu_backdrop()
	Leaderboard.wipe_leaderboard()

func _on_back_button_pressed() -> void:
	GUI.hide_pause_menu_backdrop()
