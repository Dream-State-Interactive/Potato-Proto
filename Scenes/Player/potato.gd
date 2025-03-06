extends RigidBody2D

const MAX_LEVEL: int = 3

@export var grip: float = 1.0
@export var bounce: float = 0.2
@export var weight_multiplier: float = 1.0

@export var roll_strength: float = 5000.0
@export var roll_multiplier: float = 1000.0
@export var jump_strength: float = 50.0
@export var jump_multiplier: float = 5.0

# Underwater behavior variables.
var in_water: bool = false
@export var water_impulse_strength: float = 100.0  
@export var water_build_duration: float = 3.0       
@export var water_decay_rate: float = 1.0           
var water_roll_timer: float = 0.0                   
var water_roll_start_timer: float = 0.0  # Timer to delay water impulse

# Airborne impulse variables.
@export var air_impulse_strength: float = 70.0      
@export var air_build_duration: float = 3.0         
var air_roll_timer: float = 0.0                     

var is_on_ground: bool = false
var points_available: int = 0
var speed_level: int = 0
var jump_level: int = 0

@onready var HUD: CanvasLayer = $HUD
@onready var points_label: Label = $HUD/BG/PointsLabel
@onready var speed_slots: HBoxContainer = $HUD/BG/SpeedSlots
@onready var jump_slots: HBoxContainer = $HUD/BG/JumpSlots

const WATER_IMPULSE_DELAY: float = 0.5  # Delay before impulse starts

func _ready():
	mass = weight_multiplier
	contact_monitor = true
	max_contacts_reported = 4

	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = grip
	physics_material_override.bounce = bounce

	HUD.visible = false  # Explicitly hide the HUD after update
	update_hud()  # Ensure HUD values are initialized properly

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("level_up_menu"):
		HUD.visible = !HUD.visible
		update_hud()
		print("Toggling HUD: ", HUD.visible)

	if Input.is_action_just_pressed("level_up"):
		points_available += 1
		update_hud()

	# Handle rolling input (torque-based)
	if !HUD.visible:
		var roll_dir = get_roll_direction()
		if roll_dir != 0:
			apply_torque(roll_dir * roll_strength * roll_multiplier * delta)
		if Input.is_action_pressed("stop"):
			set_angular_velocity(0)

	# Apply propulsion impulse based on state
	if in_water:
		apply_custom_impulse(delta, true)
	elif not is_on_ground:
		apply_custom_impulse(delta, false)

	if Input.is_action_just_released("scroll_up"):
		adjust_zoom(1.2)
	elif Input.is_action_just_released("scroll_down"):
		adjust_zoom(1 / 1.2)

func _physics_process(_delta: float) -> void:
	is_on_ground = get_contact_count() > 0

func _input(event: InputEvent) -> void:
	if !HUD.visible:
		if event.is_action_pressed("jump"):
			if is_on_ground:
				apply_central_impulse(Vector2(0, -jump_strength * mass * jump_multiplier))
			elif in_water:
				apply_central_impulse(Vector2(0, -jump_strength * 0.3 * mass * jump_multiplier))
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

# Determine roll direction based on input
func get_roll_direction() -> int:
	var roll_dir = 0
	if Input.is_action_pressed("roll_left"):
		roll_dir -= 1
	if Input.is_action_pressed("roll_right"):
		roll_dir += 1
	return roll_dir

# Apply impulse forces for rolling in water or air (renamed to avoid conflict)
func apply_custom_impulse(delta: float, is_water: bool) -> void:
	var roll_dir = get_roll_direction()
	
	if roll_dir == 0:
		# Reset timers if no input
		if is_water:
			water_roll_timer = max(water_roll_timer - water_decay_rate * delta, 0.0)
			water_roll_start_timer = 0.0  # Reset delay timer
		else:
			air_roll_timer = max(air_roll_timer - water_decay_rate * delta, 0.0)
		return

	if is_water:
		# Increase delay timer
		water_roll_start_timer += delta
		
		# Only start impulse after delay
		if water_roll_start_timer < WATER_IMPULSE_DELAY:
			return  # Do nothing until delay is reached

		# Normal water impulse logic
		water_roll_timer = min(water_roll_timer + delta, water_build_duration)
		var build_multiplier = water_roll_timer / water_build_duration
		var impulse_dir = Vector2(roll_dir, -0.5).normalized()
		apply_central_impulse(impulse_dir * water_impulse_strength * build_multiplier * delta)
	else:
		# Normal air impulse logic
		air_roll_timer = min(air_roll_timer + delta, air_build_duration)
		var air_build_multiplier = air_roll_timer / air_build_duration
		var impulse_dir = Vector2(roll_dir, -0.5).normalized()
		apply_central_impulse(impulse_dir * air_impulse_strength * air_build_multiplier * delta)

# Adjust camera zoom
func adjust_zoom(scale: float):
	var zoom = $Camera2D.get_zoom() * scale
	$Camera2D.set_zoom(zoom)
	print(zoom)

# When leaving water, transfer water buildup to air
func set_in_water(state: bool) -> void:
	if in_water and not state:
		air_roll_timer = max(air_roll_timer, water_roll_timer)
		water_roll_timer = 0.0
		water_roll_start_timer = 0.0  # Reset delay timer when leaving water
	in_water = state

# Level up the specified stat
func level_up(stat_name: String):
	if points_available <= 0:
		return

	match stat_name:
		"speed":
			if speed_level < MAX_LEVEL:
				speed_level += 1
				roll_multiplier *= 1.5
				water_impulse_strength *= 1.4
				air_impulse_strength *= 1.4
				points_available -= 1
		"jump":
			if jump_level < MAX_LEVEL:
				jump_level += 1
				jump_multiplier += jump_multiplier * 2.0 / 4.0
				points_available -= 1
		_:
			push_warning("Unknown stat: %s" % stat_name)
	update_hud()

# Update HUD with available points and level indicators
func update_hud():
	points_label.text = "Points Available: " + str(points_available)
	update_upgrade_buttons(speed_slots, speed_level, "speed")
	update_upgrade_buttons(jump_slots, jump_level, "jump")

# Update buttons for speed and jump upgrades
func update_upgrade_buttons(slot_container: HBoxContainer, level: int, stat_name: String):
	for i in range(MAX_LEVEL):
		var button = slot_container.get_child(i)
		button.modulate = Color("de000d") if i < level else Color("474a4a")
		button.disabled = (i > level) or (i == level and points_available == 0)
		button.set_pressed(i < level)

		if not button.is_connected("pressed", Callable(self, "level_up").bind(stat_name)):
			button.connect("pressed", Callable(self, "level_up").bind(stat_name))
