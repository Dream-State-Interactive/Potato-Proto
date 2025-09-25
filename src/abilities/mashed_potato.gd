# src/abilities/mashed_potato.gd
extends Ability

var jump_timer: Timer = Timer.new()
var hang_timer: Timer = Timer.new()
const RISE_TIME: float = 0.35
const HANG_TIME: float = 0.15
const COOLDOWN: float = 8.0
var phase = PHASES.IDLE
var directionVector: Vector2
var player_instance = null

enum PHASES {
	IDLE,
	JUMPING,
	HANG_TIME
}

func _ready():
	cooldown_duration = COOLDOWN
	hang_timer.one_shot = true
	jump_timer.one_shot = true
	add_child(hang_timer)
	add_child(jump_timer)
	super()
	
func _process(_delta: float):
	if jump_timer.is_stopped() and phase == PHASES.JUMPING:
		hang()
		
	if hang_timer.is_stopped() and phase == PHASES.HANG_TIME:
		smash_down()
		
	super(_delta)

func perform_ability(player_body: RigidBody2D):
	player_instance = player_body
	var roll_input = Input.get_axis("roll_left", "roll_right")
	directionVector = Vector2.RIGHT
	if roll_input < 0:
		directionVector = Vector2.LEFT
		
	jump()
	
func jump():
	phase = PHASES.JUMPING
	GameManager.player_instance.apply_central_impulse(Vector2.UP * GameManager.player_instance.stats.jump_force * 30)
	jump_timer.start(RISE_TIME)

func hang():
	phase = PHASES.HANG_TIME
	GameManager.player_instance.linear_velocity = Vector2.ZERO
	GameManager.player_instance.angular_velocity = 0.0
	#turn off player gravity
	#rotate slowly

	hang_timer.start(HANG_TIME)

func smash_down():
	phase = PHASES.IDLE
	
	# Crash down hard
	GameManager.player_instance.apply_central_impulse((directionVector + Vector2.DOWN) * GameManager.player_instance.stats.jump_force * 40)
	
	#turn player gravity back on
	
