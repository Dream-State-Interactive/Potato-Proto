# src/ui/hud.gd 
extends CanvasLayer

# --- Node References ---
@onready var health_bar: ProgressBar = $TopLeft_VBox/HealthBar
@onready var starch_label: Label = $TopLeft_VBox/StarchLabel
@onready var ability1_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability1_Icon/Ability1_CooldownBar
@onready var ability2_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability2_Icon/Ability2_CooldownBar

# --- Godot Functions ---
func _ready():
	# Configure progress bars for the 0.0-1.0 signal from the ability
	ability1_cooldown_bar.max_value = 1.0
	ability2_cooldown_bar.max_value = 1.0
	ability1_cooldown_bar.value = 0.0
	ability2_cooldown_bar.value = 0.0
	# Wait one frame to guarantee all @onready vars are loaded.
	await get_tree().process_frame


# --- Public API (Functions called from outside) ---
# These functions are now guaranteed to be safe because they will only
# be connected by the GameManager AFTER _ready() has fully completed.

func connect_to_game_manager_signals():
	print("HUD: Connecting to GameManager & Player signals.")
	
	# Connect ALL UI update functions ONLY to the GameManager's global signals.
	GameManager.starch_changed.connect(update_starch_label)
	GameManager.player_health_updated.connect(update_health_bar)
	GameManager.ability1_cooldown_updated.connect(update_ability1_cooldown)
	GameManager.ability2_cooldown_updated.connect(update_ability2_cooldown)
	
	# Immediately pull the initial state from the GameManager to sync up.
	update_starch_label(GameManager.current_starch_points)
	if is_instance_valid(GameManager.player_instance):
		var health_comp = GameManager.player_instance.health_component
		if is_instance_valid(health_comp):
			update_health_bar(health_comp.current_health, health_comp.max_health)



func update_health_bar(current: float, max_health: float):
	health_bar.max_value = max_health
	health_bar.value = current

func update_starch_label(new_amount: int):
	starch_label.text = "Starch: %s" % new_amount

func update_ability1_cooldown(progress: float):
	ability1_cooldown_bar.value = progress

func update_ability2_cooldown(progress: float):
	ability2_cooldown_bar.value = progress
	
