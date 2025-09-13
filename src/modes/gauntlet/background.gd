# src/modes/gauntlet/background.gd
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect
var active_tween: Tween

func _ready():
	color_rect.color = ThemeManager.get_current_theme().sky_color

func change_color(new_color: Color, duration: float = 2.0):
	# If a transition is already running, kill the old tween to start a new one.
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# Create a new tween. It will be managed and freed automatically.
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE) # Makes the transition smoother
	active_tween.tween_property(color_rect, "color", new_color, duration)
