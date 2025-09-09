# src/ui/hud.gd 
extends CanvasLayer

# --- Node References ---
@onready var health_bar: ProgressBar = $TopLeft_VBox/HealthBar
@onready var starch_label: Label = $TopLeft_VBox/StarchLabel
@onready var ability1_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability1_Icon/Ability1_CooldownBar
@onready var ability2_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability2_Icon/Ability2_CooldownBar
@onready var ability1_icon: TextureRect = $BottomRight_HBox/Ability1_Icon
@onready var ability2_icon: TextureRect = $BottomRight_HBox/Ability2_Icon

var speed
var FPS
var score
const SPEED_NORMALIZER = 100

func _ready():
	# Configure progress bars for the 0.0-1.0 signal from the ability
	ability1_cooldown_bar.max_value = 1.0
	ability2_cooldown_bar.max_value = 1.0
	ability1_cooldown_bar.value = 0.0
	ability2_cooldown_bar.value = 0.0
	# Wait one frame to guarantee all @onready vars are loaded.
	await get_tree().process_frame

func _process(delta: float) -> void:
	FPS = 1/delta
	$TopLeft_VBox/FPSLabel.text = str("FPS: " + str(int(FPS)))
	if GameManager.is_player_active():
		speed = int(GameManager.player_instance.linear_velocity.length() / SPEED_NORMALIZER)
		$TopLeft_VBox/SpeedLabel.text = (str(int(speed)) + " MPH")
		score = int(GameManager.player_instance.score)
		$TopLeft_VBox/ScoreLabel.text = "SCORE: " + str(score)


func connect_to_game_manager_signals():
	print("HUD: Connecting to GameManager & Player signals.")
	
	# Connect ALL UI update functions ONLY to the GameManager's global signals.
	GameManager.starch_changed.connect(update_starch_label)
	GameManager.player_health_updated.connect(update_health_bar)
	GameManager.ability1_cooldown_updated.connect(update_ability1_cooldown)
	GameManager.ability2_cooldown_updated.connect(update_ability2_cooldown)
	GameManager.ability1_equipped.connect(update_ability1_icon)
	GameManager.ability2_equipped.connect(update_ability2_icon)
	
	# Immediately pull the initial state from the GameManager to sync up.
	update_starch_label(GameManager.current_starch_points)
	if is_instance_valid(GameManager.player_instance):
		var health_comp = GameManager.player_instance.health_component
		if is_instance_valid(health_comp):
			update_health_bar(health_comp.current_health, health_comp.max_health)
		update_ability1_icon(GameManager.player_instance.equipped_ability1_info)
		update_ability2_icon(GameManager.player_instance.equipped_ability2_info)



func update_health_bar(current: float, max_health: float):
	health_bar.max_value = max_health
	health_bar.value = current

func update_starch_label(new_amount: int):
	starch_label.text = "Starch: %s" % new_amount

func update_ability1_cooldown(progress: float):
	ability1_cooldown_bar.value = progress

func update_ability2_cooldown(progress: float):
	ability2_cooldown_bar.value = progress
	
func update_ability1_icon(ability_info: AbilityInfo):
	if ability_info and ability_info.icon:
		ability1_icon.texture = ability_info.icon
	else:
		# If no ability is equipped, clear the texture.
		ability1_icon.texture = null

func update_ability2_icon(ability_info: AbilityInfo):
	if ability_info and ability_info.icon:
		ability2_icon.texture = ability_info.icon
	else:
		# If no ability is equipped, clear the texture.
		ability2_icon.texture = null
