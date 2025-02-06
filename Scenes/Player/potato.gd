extends RigidBody2D

@export var grip: float = 1.0
@export var bounce: float = 0.2
@export var weight_multiplier: float = 1.0

@export var roll_strength: float = 5000.0
@export var roll_multiplier: float = 1000.0
@export var jump_strength: float = 50.0
@export var jump_multiplier: float = 5.0

var is_on_ground: bool = false
var points_available: int = 0  # Start with 0 points
var speed_level: int = 0
var jump_level: int = 0

@onready var HUD: CanvasLayer = $HUD
@onready var points_label: Label = $HUD/BG/PointsLabel
@onready var speed_slots: HBoxContainer = $HUD/BG/SpeedSlots
@onready var jump_slots: HBoxContainer = $HUD/BG/JumpSlots


func _ready():
	mass = weight_multiplier

	# Enable contact monitoring
	contact_monitor = true
	max_contacts_reported = 4  # Adjust as needed

	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()

	physics_material_override.friction = grip
	physics_material_override.bounce = bounce

	# Hide HUD initially
	HUD.visible = false
	update_hud()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("level_up_menu"):
		HUD.visible = !HUD.visible  # Toggle HUD visibility
		update_hud() # Update the HUD when the menu opens or closes
		print("Toggling HUD: ", HUD.visible)
	if Input.is_action_just_pressed("level_up"):
		points_available += 1
		update_hud()
	# Handle rolling input
	if !HUD.visible:  # Only process movement if HUD is *not* visible
		if Input.is_action_pressed("roll_left"):
			apply_torque(-roll_strength * roll_multiplier * delta)
		if Input.is_action_pressed("roll_right"):
			apply_torque(roll_strength * roll_multiplier * delta)
		if Input.is_action_pressed("stop"):
			set_angular_velocity(0)
			
	if Input.is_action_just_released("scroll_up"):
		var zoom := Vector2($Camera2D.get_zoom())
		zoom *= 1.2
		$Camera2D.set_zoom(zoom)
		print(zoom)
	elif Input.is_action_just_released("scroll_down"):
		var zoom := Vector2($Camera2D.get_zoom())
		zoom *= 1/1.2
		$Camera2D.set_zoom(zoom)
		print(zoom)
	elif Input.is_action_pressed("space"):
		set_angular_velocity(0)      

func _physics_process(delta: float) -> void:
	# Update ground detection
	is_on_ground = get_contact_count() > 0

func _input(event: InputEvent) -> void:
	if !HUD.visible: # Only process jump input when HUD not visible
		if event.is_action_pressed("jump") and is_on_ground:
			apply_central_impulse(Vector2(0, -jump_strength * mass * jump_multiplier))
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func level_up(stat_name: String):
	if points_available <= 0:
		return

	match stat_name:
		"speed":
			if speed_level < 3: # Add the max level check
				speed_level += 1
				roll_multiplier *= 1.5
				points_available -= 1
		"jump":
			if jump_level < 3: # Add the max level check
				jump_level += 1
				jump_multiplier += jump_multiplier * 2.0 / 4.0
				points_available -= 1
		_:
			push_warning("Unknown stat: %s" % stat_name)

	update_hud() # Updates after successful level up


func update_hud():
	points_label.text = "Points Available: " + str(points_available)

	for i in range(3):
		var speed_button = speed_slots.get_child(i)
		var jump_button = jump_slots.get_child(i)

		# --- Speed Button Logic ---
		if i < speed_level:
			speed_button.modulate = Color("de000d")  # Red for achieved levels
		else:  # All other levels are grey, including the current level (i == speed_level)
			speed_button.modulate = Color("474a4a")  # Grey for current and future levels

		speed_button.disabled = (i > speed_level) or (i == speed_level and points_available == 0)
		speed_button.set_pressed(i < speed_level)  # Pressed for achieved levels

		# Connect speed button signal 
		if not speed_button.disabled and not speed_button.is_connected("pressed", Callable(self, "level_up").bind("speed")):
			speed_button.connect("pressed", Callable(self, "level_up").bind("speed"))

		# --- Jump Button Logic (identical to speed button) ---
		if i < jump_level:
			jump_button.modulate = Color("de000d")  # Red for achieved levels
		else:  # All other levels are grey, including the current level (i == jump_level)
			jump_button.modulate = Color("474a4a")  # Grey for current and future levels

		jump_button.disabled = (i > jump_level) or (i == jump_level and points_available == 0)
		jump_button.set_pressed(i < jump_level) # Pressed for achieved levels

		# Connect jump button signal
		if not jump_button.disabled and not jump_button.is_connected("pressed", Callable(self, "level_up").bind("jump")):
			jump_button.connect("pressed", Callable(self, "level_up").bind("jump"))
