# src/modes/gauntlet/store_interaction.gd
extends Area2D

@export var store_type: StoreType = StoreType.LEVEL_UP

enum StoreType {
	LEVEL_UP,
	ABILITY
}

@onready var prompt_label: Label = $"../PromptLabel"

var player_in_area: bool = false


func _ready():
	prompt_label.visible = false
	body_entered.connect(func(body):
		if body.is_in_group("player"):
			player_in_area = true
			prompt_label.visible = true
	)
	body_exited.connect(func(body):
		if body.is_in_group("player"):
			player_in_area = false
			prompt_label.visible = false
	)

func _process(_delta):
	if player_in_area and Input.is_action_just_pressed("interact"):
		print("STORE INTERACTION: Opening store UI...")
		match store_type:
			StoreType.LEVEL_UP:
				GUI.toggle_level_up_menu()
			StoreType.ABILITY:
				GUI.toggle_ability_menu()
