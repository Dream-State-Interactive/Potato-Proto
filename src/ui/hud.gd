# src/ui/hud.gd (Final Corrected Version)
extends CanvasLayer

# --- Node References ---
@onready var health_bar: ProgressBar = $TopLeft_VBox/HealthBar
@onready var starch_label: Label = $TopLeft_VBox/StarchLabel
@onready var ability1_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability1_Icon/Ability1_CooldownBar
@onready var ability2_cooldown_bar: ProgressBar = $BottomRight_HBox/Ability2_Icon/Ability2_CooldownBar

# --- Godot Functions ---
func _ready():
	# Wait one frame to guarantee all @onready vars are loaded.
	await get_tree().process_frame
	# Now, tell the GameManager that this specific instance is ready to be used.
	GameManager.on_hud_ready(self)


# --- Public API (Functions called from outside) ---
# These functions are now guaranteed to be safe because they will only
# be connected by the GameManager AFTER _ready() has fully completed.

func update_health_bar(current: float, max: float):
	health_bar.max_value = max
	health_bar.value = current

func update_starch_label(new_amount: int):
	starch_label.text = "Starch: %s" % new_amount

func connect_ability_signals(player: Player):
	if player.ability1_slot.get_child_count() > 0:
		var ability1 = player.ability1_slot.get_child(0) as Ability
		ability1.cooldown_updated.connect(update_ability1_cooldown)
	if player.ability2_slot.get_child_count() > 0:
		var ability2 = player.ability2_slot.get_child(0) as Ability
		ability2.cooldown_updated.connect(update_ability2_cooldown)

func update_ability1_cooldown(progress: float):
	ability1_cooldown_bar.value = progress * 100

func update_ability2_cooldown(progress: float):
	ability2_cooldown_bar.value = progress * 100
