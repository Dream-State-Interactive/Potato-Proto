# =============================================================================
# c_launcher.gd - A Universal Projectile Launcher Component
# =============================================================================
#
# WHAT IT IS:
# A reusable component that can be placed anywhere in a level to spawn and
# launch other scenes (like the Knife) as projectiles.
#
# ARCHITECTURE:
# - It is highly configurable through the Inspector, allowing designers to
#   create turrets, cannons, or droppers without writing any code.
# - It uses a Timer for its firing rate.
# - It has logic to aim either at a fixed angle or dynamically track a target node.
#
# =============================================================================
class_name CLauncher
extends Node2D

# --- Configuration ---
## The scene file (.tscn) of the object to be launched (e.g., knife.tscn).
@export var projectile_scene: PackedScene

@export_group("Launch Physics")
## The initial speed of the projectile in pixels per second.
@export var launch_speed: float = 800.0
## The launch angle in degrees if no target is set. A dial is provided by an addon.
@export_range(-180, 180) var launch_degree_angle: float = -90.0
## Overrides the projectile's gravity scale. Higher values create a more pronounced arc.
@export var launch_arc_gravity_scale: float = 2.0

@export_group("Timing")
## The time in seconds between each shot.
@export var fire_rate_seconds: float = 3.0
## The delay in seconds before the first shot is fired.
@export var start_delay: float = 1.0
## If true, the launcher will fire continuously. If false, it fires only once.
@export var auto_fire: bool = true

@export_group("Orientation & Targeting")
## If checked, the projectile's rotation will be set to match its launch direction.
@export var orient_to_launch_angle: bool = true
## If you assign a NodePath to another node (like the Player), the launcher
## will ignore 'launch_degree_angle' and aim at the target instead.
@export var target_node_path: NodePath

# --- Node References ---
@onready var launch_point = $LaunchPoint
@onready var timer = $Timer

# --- Godot Functions ---
func _ready():
	# Configure the timer based on our exported variables.
	timer.wait_time = fire_rate_seconds
	timer.one_shot = not auto_fire
	timer.autostart = false # We control the start manually.
	
	timer.timeout.connect(fire)
	
	# We use a one-off timer created in code to handle the initial start delay.
	# `await` pauses the execution of this function until the timer finishes.
	var start_timer = get_tree().create_timer(start_delay)
	await start_timer.timeout
	
	# After the delay, if auto-fire is on, we start the main timer and fire the first shot.
	if auto_fire:
		timer.start()
		fire()

# --- Core Logic ---
## This function is called by the Timer's 'timeout' signal.
func fire():
	if not projectile_scene: return
	
	# Create an instance of our projectile scene.
	var projectile = projectile_scene.instantiate()
	
	# It's best practice to add projectiles to the main scene root. This prevents
	# them from being destroyed if the launcher itself is destroyed mid-flight.
	get_tree().get_root().add_child(projectile)
	
	# Place the new projectile at our designated launch point.
	projectile.global_position = launch_point.global_position
	
	# --- Calculate Launch Direction ---
	# Default direction is based on the angle set in the Inspector.
	var launch_direction = Vector2.RIGHT.rotated(deg_to_rad(launch_degree_angle))
	
	# If a target node has been assigned, override the direction.
	var target = get_node_or_null(target_node_path)
	if is_instance_valid(target):
		launch_direction = (target.global_position - launch_point.global_position).normalized()
	
	# Set the projectile's visual rotation if toggled.
	if orient_to_launch_angle:
		projectile.rotation = launch_direction.angle()
	
	# --- Apply Physics ---
	# We check if the projectile is a physics body before trying to apply forces.
	if projectile is RigidBody2D:
		projectile.gravity_scale = launch_arc_gravity_scale
		projectile.linear_velocity = launch_direction * launch_speed
