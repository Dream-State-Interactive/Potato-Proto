# =============================================================================
# player.gd - The Sentient Potato
# =============================================================================
#
# WHAT IT IS:
# This script defines the behavior for the main player character. It is the
# central hub for movement, abilities, stats, and visual effects. It is
# built on Godot's RigidBody2D for realistic physics-based movement.
#
# ARCHITECTURE:
# - It is data-driven, getting its core physics properties from a 'StatBlock' Resource.
# - It uses a component-based design, delegating complex behaviors like health
#   management ('CHealth') and wall-climbing ('CGrip') to child nodes.
# - It manages its own state (e.g., _is_gripping, can_jump) to decide which
#   physics logic to apply on any given frame.
#
# =============================================================================
class_name Player
extends RigidBody2D

signal landed
signal left_ground
signal player_death(score: int)

var can_air_dash := false
var dashes_used: int = 0
var _was_on_floor := false

const DASHES_AVAILABLE = 2
const STARCH_HEAL_VALUE = 2
const SCORE_DISTANCE_NORMALIZER = 0.1
const SCORE_POINTS_NORMALIZER = 10

const FLOOR_ANGLE_MAX := deg_to_rad(50.0)   # treat anything flatter than this as floor

# =============================================================================
# --- EXPORTED VARIABLES (Configured in the Godot Inspector) ---
# =============================================================================

## The single source of truth for all player stats. This is assigned by the
## GameManager at runtime to ensure consistency across new games and loaded games.
@export var stats: StatBlock

@export var DEV_ROLL_MULTIPLIER: float = 1.0

## A reference to the AbilityInfo resource for the first slot (Q key).
@export var equipped_ability1_info: AbilityInfo
## A reference to the AbilityInfo resource for the second slot (E key).
@export var equipped_ability2_info: AbilityInfo

## A gameplay toggle. If true, the player will not take damage when the
## high-speed circle collider is active.
@export var invincible_at_high_speed: bool = true
@export var INDESTRUCTIBLE_VELOCITY: float = 4000.0

# player.gd

# ... (add this with your other exported variables) ...

@export_group("Visuals")
## The radius of the peel effect in the shader (in UV space, 0.0 to 1.0).
@export var peel_shader_radius: float = 0.2

@export_group("Aging")
## How many seconds it takes for the player to go from 0% health to fully "aged"
## (i.e., the flesh sprite becomes fully darkened).
@export var seconds_to_fully_age: float = 20.0

@export_group("Target Collision Sizes")
## The target radius for the capsule shape at medium speed.
@export var target_capsule_radius: float = 22.0
## The target height for the capsule shape at medium speed.
@export var target_capsule_height: float = 90.0
## The target radius for the final circle shape at high speed.
@export var target_circle_radius: float = 45.0

@export_group("Stat Properties")
@export var roll_strength: float = 5000.0
@export var roll_multiplier: float = 1000.0
@export var jump_strength: float = 50.0
@export var jump_multiplier: float = 5.0

@export var score = 0

var prevDistance: float = 0

const DASH_COOLDOWN: float = 0.125
const COMBO_COOLDOWN: float = 0.25

## The speed (in pixels/sec) at which the collision shape starts blending
## from the detailed polygon to the smoother capsule shape.
const low_speed_threshold: float = 5
## The speed at which the blend to the capsule is complete, and the blend
## from capsule to a perfect circle begins.
const mid_speed_threshold: float = 10
## The speed at which the player's collision is a perfect circle for smooth rolling.
const high_speed_threshold: float = 12


# =============================================================================
# --- NODE REFERENCES (@onready vars) ---
# =============================================================================
# These variables get a direct reference to the child nodes in the scene tree.

# --- Components ---
@onready var health_component: CHealth = $HealthComponent
@onready var armor_component: CArmor = $ArmorComponent
@onready var grip_component: CGrip = $GripComponent

# --- Visuals ---
@onready var skin_sprite: Sprite2D = $SkinSprite
@onready var flesh_sprite: Sprite2D = $FleshSprite

# --- Timers ---
@onready var damage_cooldown: Timer = $DamageCooldownTimer
@onready var coyote_timer: Timer = $CoyoteTimer

# --- Abilities ---
@onready var ability1_slot: Node = $Ability1_Slot
@onready var ability2_slot: Node = $Ability2_Slot

# --- Collision Shapes ---
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var collision_capsule: CollisionShape2D = $CollisionCapsule2D
@onready var collision_circle: CollisionShape2D = $CollisionCircle2D
@onready var InputCooldownTimer: Timer = $InputCooldown
@onready var ComboCooldownTimer: Timer = $ComboCooldown
@onready var GroundRay: RayCast2D = $GroundRay


# =============================================================================
# --- INTERNAL STATE VARIABLES ---
# =============================================================================
var roll_input: float = 0.0                # The current player input (-1 for left, 1 for right).
var damage_points: PackedVector2Array = []     # Stores the UV coordinates for each peel decal.
var current_aging_level: float = 0.0       # The current "darkness" of the flesh (0.0 to 1.0).
var aging_rate: float = 0.0                # How fast the aging level increases per second.
var can_jump: bool = false                 # A flag for the Coyote Time system.
var original_polygon_points: PackedVector2Array # A backup of the detailed collision shape.
var _is_gripping: bool = false             # Tracks if the CGrip component is currently active.
var ready_for_combo = false
var _skin_material_made_unique: bool = false


# =============================================================================
# --- GODOT BUILT-IN FUNCTIONS ---
# =============================================================================

# _ready() runs once when the node is added to the scene tree and ready.
# It's used for one-time setup.
func _ready():
	InputCooldownTimer.wait_time = DASH_COOLDOWN
	ComboCooldownTimer.wait_time = COMBO_COOLDOWN
	# --- Physics Setup ---
	contact_monitor = true  # Essential for RigidBody2D to report collisions.
	max_contacts_reported = 8 # How many simultaneous collisions to track.
	apply_stats_from_resource() # Apply stats from the StatBlock for the first time.

	# --- Component & Signal Connections ---
	# We connect to the signals from our HealthComponent. This allows this script
	# to react when health changes or the player dies.
	health_component.damaged.connect(_on_damaged)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	# Make the materials unique to this player instance.
	# This prevents them from being reset to default on scene reload.
	#if skin_sprite.material:
		#skin_sprite.material = skin_sprite.material.duplicate()
	#if flesh_sprite.material:
		#flesh_sprite.material = flesh_sprite.material.duplicate()
	
	# --- Visuals & Ability Setup ---
	# Initialize the peeling shader to have zero holes at the start.
	var skin_material = skin_sprite.material as ShaderMaterial
	if skin_material:
		skin_material.set_shader_parameter("hit_count", 0)
		skin_material.set_shader_parameter("hit_points", []) 
	
	# Equip the abilities assigned in the Inspector.
	equip_ability(equipped_ability1_info, 1)
	equip_ability(equipped_ability2_info, 2)
	
	# Announce our existence to the GameManager, which will give us our stats
	# and wire us up to the rest of the game.
	GameManager.register_player(self, health_component)
	
	# --- Dynamic Collision Setup ---
	# Store the original shape of the polygon so we can scale it down later without losing data.
	original_polygon_points = collision_polygon.polygon

	# Initialize the other shapes to be effectively non-existent.
	collision_capsule.shape.radius = 0.01
	collision_capsule.shape.height = 0.0
	collision_circle.shape.radius = 0.01

# _process(delta) runs on every visual frame. Ideal for visual-only updates.
func _process(delta: float):
	# Handle the continuous "aging" of the potato flesh.
	if aging_rate > 0:
		# Increase the aging level over time, scaled by delta to be frame-rate independent.
		current_aging_level = clamp(current_aging_level + (aging_rate * delta), 0.0, 1.0)
		
		# Update the "aging_factor" uniform in the flesh sprite's shader.
		var flesh_material = flesh_sprite.material as ShaderMaterial
		if flesh_material:
			flesh_material.set_shader_parameter("aging_factor", current_aging_level)
			
	generate_score()
			
	#if Input.is_action_just_released("scroll_up"):
		#adjust_zoom(1.2)
	#elif Input.is_action_just_released("scroll_down"):
		#adjust_zoom(1 / 1.2)
		
func generate_score():
	var player_position = global_transform.origin
	var root_position = Vector2(0,0)
	var distanceFromRoot = player_position.distance_to(root_position) - 414
	var distanceFactor = distanceFromRoot * SCORE_DISTANCE_NORMALIZER
	
	var pointsFactor = GameManager.total_starch_points * SCORE_POINTS_NORMALIZER
	
	var new_score = distanceFactor + pointsFactor
	
	if(new_score > score):
		score = new_score

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		dash("up")
	if event.is_action_pressed("down"):
		dash("down")
	if event.is_action_pressed("left"):
		dash("left")
	if event.is_action_pressed("right"):
		dash("right")

## Adjust camera zoom
#func adjust_zoom(adjustScale: float):
	#var zoom = $Camera2D.get_zoom() * adjustScale
	#$Camera2D.set_zoom(zoom)
	#print(zoom)

# _integrate_forces(state) is a special physics callback for RigidBody2D.
# It runs BEFORE the physics engine solves collisions for the frame, giving us
# a chance to directly read and modify the body's state (like velocity and forces).
# This is the most powerful and precise place to handle custom physics interactions.
func _integrate_forces(state: PhysicsDirectBodyState2D):
	
	# --- 1. GRIP LOGIC: DELEGATION PATTERN ---
	# Before doing anything else, we check if our advanced grip mechanic should take over.
	# The 'process_grip_physics' function in our component is a "black box"; it contains
	# all the complex math for wall-climbing. We just give it the data it needs.
	# The check for `stats.grip > 1` is your temporary toggle for testing the feature.
	if stats.grip > 1 and grip_component.process_grip_physics(state, roll_input):
		# If the component returns 'true', it means it has successfully taken control
		# of the player's velocity for this frame to simulate climbing.
		_is_gripping = true
		# We must 'return' immediately to prevent any of our normal physics logic
		# (like applying gravity or rolling torque) from running and interfering.
		return

	# If we reach this point, it means the grip component was not active.
	_is_gripping = false
	
	# --- 2. INVINCIBILITY LOGIC ---
	# Here we determine the player's state based on gameplay rules.
	var is_invincible = false
	if invincible_at_high_speed:
		# The condition for invincibility is that our high-speed circle collider
		# is active (not disabled) AND has grown to at least 95% of its final size.
		if not collision_circle.disabled and collision_circle.shape.radius >= target_circle_radius * 0.95 and linear_velocity.length() > INDESTRUCTIBLE_VELOCITY:
			is_invincible = true
			
	# --- 3. HAZARD COLLISION & DAMAGE LOGIC ---
	# We only check for damage if our damage cooldown timer is finished.
	# This prevents taking damage every single frame while touching a hazard.
	if damage_cooldown.is_stopped():
		# 'get_contact_count()' tells us how many objects we are touching this frame.
		for i in range(state.get_contact_count()):
			# 'get_contact_collider_object()' gives us a direct reference to the other node.
			var collider = state.get_contact_collider_object(i)
			if not collider: continue # Safety check in case the object was just freed.

			# We check if the object we hit has our reusable CHazard component.
			# The 'false, false' arguments make it a non-recursive search, which is faster.
			var hazard_component = collider.get_node_or_null("CHazard")
			if hazard_component:
				# We hit a hazardous object! Now, we need to find out WHICH PART we hit.
				
				# 'get_contact_collider_shape()' gives us the INDEX of the shape on the OTHER body
				# that was involved in the collision. e.g., 0 for the handle, 1 for the blade.
				var collider_shape_idx = state.get_contact_collider_shape(i)
				
				# 'shape_find_owner()' maps that shape index back to its owner ID. This is the
				# most reliable way to identify a specific part of a multi-shape body.
				var owner_id = -1
				if collider.has_method("shape_find_owner"):
					owner_id = collider.shape_find_owner(collider_shape_idx)
				
				# We now ask the hazard component itself: "Is this owner ID one of the shapes
				# you identified as dangerous in your _ready() function?"
				if hazard_component.is_hazard_shape(owner_id):
					# If it returns true, we can apply damage.
					if not is_invincible:
						var dmg = hazard_component.damage
						# 'get_contact_local_position()' returns the contact point in GLOBAL coordinates,
						# despite its confusing name. This is the data we need for the peeling effect.
						var global_contact_point = state.get_contact_local_position(i)
						
						# We tell our HealthComponent to process the damage, passing along the
						# precise contact point for the visual effect.
						health_component.take_damage(dmg, global_contact_point, Vector2.ZERO)
						damage_cooldown.start()
						# We 'break' out of the loop because we only want to process one
						# damage event per frame to avoid bugs.
						break
					else:
						print("INVINCIBLE: Damage ignored!")

# _physics_process(delta) runs on every physics frame. Ideal for applying forces and input.
func _physics_process(_delta: float):
	var on_floor := _is_on_floor()

	# --- DASH/JUMP LOGIC ---
	if on_floor and not _was_on_floor:
		emit_signal("landed")
		coyote_timer.stop()
		can_air_dash = false
		dashes_used = 0
		can_jump = true
	elif not on_floor and _was_on_floor:
		emit_signal("left_ground")
		coyote_timer.start()
		can_air_dash = true
		can_jump = false

	_was_on_floor = on_floor

	# Update collision shapes based on current speed.
	update_collision_shapes(angular_velocity)

	
	# --- MOVEMENT LOGIC ---
	roll_input = Input.get_axis("roll_left", "roll_right")
	
	# Only apply standard rolling torque if our advanced grip is not active.
	if not _is_gripping and roll_input != 0:
		# Note: We do not multiply by delta here. `apply_torque` is an acceleration,
		# and the physics engine handles the time step integration for us.
		apply_torque(roll_input * stats.roll_speed * DEV_ROLL_MULTIPLIER)
	
	# The horizontal nudge helps counter friction and makes movement feel more responsive.
	if on_floor and roll_input != 0:
		apply_central_force(Vector2(roll_input * stats.horizontal_nudge, 0))
	
	# --- JUMP LOGIC ---
	# We can jump if we are physically on the ground OR if the coyote timer is still running.
	if Input.is_action_just_pressed("jump") and (on_floor or not coyote_timer.is_stopped()):
		coyote_timer.stop() # Prevent double-jumps
		can_jump = false
		
		# Reset vertical velocity for a consistent jump height.
		linear_velocity.y = 0
		apply_central_impulse(Vector2.UP * stats.jump_force * 10)
		
		_is_gripping = false # Ensure grip is broken immediately on jump.
		
func _is_on_floor() -> bool:
	GroundRay.global_rotation = 0
	if not GroundRay or not GroundRay.is_enabled():
		return false
	if not GroundRay.is_colliding():
		return false
	var n := GroundRay.get_collision_normal()
	return n.angle_to(Vector2.UP) <= FLOOR_ANGLE_MAX

func _is_colliding_with_object() -> bool:
	return get_colliding_bodies().size() > 0

func dash(direction: String) -> void:
	if(can_air_dash and dashes_used < DASHES_AVAILABLE):
		if(InputCooldownTimer.is_stopped()):
			var combo_multiplier = 1
			if(!ComboCooldownTimer.is_stopped()):
				combo_multiplier = 10
			match(direction):
				"up":
					apply_central_impulse(Vector2(0, -jump_strength * mass * jump_multiplier * combo_multiplier))
				"down":
					apply_central_impulse(Vector2(0, jump_strength * mass * jump_multiplier * combo_multiplier))
				"left":
					apply_central_impulse(Vector2(-jump_strength * mass * jump_multiplier * combo_multiplier, 0))
				"right":
					apply_central_impulse(Vector2(jump_strength * mass * jump_multiplier * combo_multiplier, 0))
			InputCooldownTimer.start()
			
		dashes_used += 1

func _on_input_cooldown_timeout() -> void:
	ready_for_combo = true
	ComboCooldownTimer.start()
	
func _on_combo_cooldown_timeout() -> void:
	ready_for_combo = false

# _unhandled_input(event) processes input events that haven't been consumed by the UI.
# It's the best place for single-press game actions like abilities.
func _unhandled_input(event: InputEvent):
	# Guard clause to ignore irrelevant events like mouse motion.
	if not (event is InputEventKey or event is InputEventMouseButton):
		return
		
	# Activate abilities. The ability nodes themselves handle their cooldowns.
	if event.is_action_pressed("ability_1"):
		if ability1_slot.get_child_count() > 0:
			(ability1_slot.get_child(0) as Ability).activate(self)
			
	if event.is_action_pressed("ability_2"):
		if ability2_slot.get_child_count() > 0:
			(ability2_slot.get_child(0) as Ability).activate(self)

# =============================================================================
# --- CUSTOM FUNCTIONS ---
# =============================================================================

# This function is called by the SaveManager after loading data.
# It forces all visuals to update to the new loaded state.
func force_visual_update():
	
	# For debugging, let's be 100% sure the data is correct right here.
	print("Forcing visual update. Damage points count: ", damage_points.size())
	if not damage_points.is_empty():
		print("First damage point: ", damage_points[0])
	
	# Update the peel shader
	var skin_material = skin_sprite.material as ShaderMaterial
	if skin_material:
		skin_material.set_shader_parameter("peel_radius", peel_shader_radius)
		skin_material.set_shader_parameter("hit_points", damage_points)
		skin_material.set_shader_parameter("hit_count", damage_points.size())
		
	print(skin_material.get_shader_parameter("hit_count"))
	print(skin_material.get_shader_parameter("hit_points"))
	# Update the aging shader and the HUD health bar.
	_on_health_changed(health_component.current_health, stats.max_health)

# This function is connected to the HealthComponent's 'damaged' signal.
# It handles the visual effect of peeling the skin.
func _on_damaged(amount: float, global_contact_point: Vector2, contact_normal: Vector2):
	_ensure_skin_material_is_unique()
	if damage_points.size() >= 64: return

	# This block converts the global collision point into a 0-1 UV coordinate
	# on the skin sprite's texture, accounting for the sprite's position and size.
	var local_point_on_sprite = skin_sprite.to_local(global_contact_point)
	var texture_size = skin_sprite.texture.get_size()
	var point_from_topleft = local_point_on_sprite + (texture_size / 2.0)
	var uv_position = point_from_topleft / texture_size
	
	# Clamp the UVs to ensure the peel mark always appears on the sprite, even
	# if the collision happened on an oversized collision shape.
	uv_position.x = clamp(uv_position.x, 0.0, 1.0)
	uv_position.y = clamp(uv_position.y, 0.0, 1.0)

	damage_points.append(uv_position)

	# Send the updated list of damage points to the shader.
	var skin_material = skin_sprite.material as ShaderMaterial
	if skin_material:
		skin_material.set_shader_parameter("peel_radius", peel_shader_radius)
		skin_material.set_shader_parameter("hit_points", damage_points)
		skin_material.set_shader_parameter("hit_count", damage_points.size())

# This is connected to the HealthComponent's 'health_changed' signal.
# It calculates the new rate of aging based on how much health is missing.
func _on_health_changed(current_health: float, max_health: float):
	var max_aging_rate = 0.0
	if seconds_to_fully_age > 0:
		max_aging_rate = 1.0 / seconds_to_fully_age
	var health_percentage = current_health / max_health
	aging_rate = (1.0 - health_percentage) * max_aging_rate

func _on_ability1_cooldown_updated(progress: float):
	GameManager.ability1_cooldown_updated.emit(progress)

func _on_ability2_cooldown_updated(progress: float):
	GameManager.ability2_cooldown_updated.emit(progress)

# The public healing function. Called by 'add_starch'.
func heal(amount: float):
	var max_health = stats.max_health
	if max_health <= 0: return

	var heal_percentage = amount / max_health
	
	# Tell the HealthComponent to restore health. This will trigger _on_health_changed.
	health_component.heal(amount)
	
	# Visually "un-peel" by removing the most recent damage point.
	if not damage_points.is_empty():
		damage_points.resize(damage_points.size() - 1)
		# Force the shader to update with the smaller list of damage points.
		var skin_material = skin_sprite.material as ShaderMaterial
		if skin_material:
			skin_material.set_shader_parameter("hit_points", damage_points)
			skin_material.set_shader_parameter("hit_count", damage_points.size())
			
	# Directly reverse the aging effect.
	current_aging_level = clamp(current_aging_level - heal_percentage, 0.0, 1.0)
	var flesh_material = flesh_sprite.material as ShaderMaterial
	if flesh_material:
		flesh_material.set_shader_parameter("aging_factor", current_aging_level)

# This is called by StarchPoint collectibles.
func add_starch(amount: int):
	GameManager.add_starch_points(amount)
	heal(STARCH_HEAL_VALUE) # Each starch point heals for a flat amount.

# This is connected to the HealthComponent's 'died' signal.
func _on_died():
	print("Player has died!")
	player_death.emit(score)
	score = 0
	SceneLoader.change_scene("res://src/ui/menus/leaderboardDeath.tscn")

# This function is called from _ready() and by the GameManager after an upgrade/load.
# It ensures the player's physics properties match the current StatBlock resource.
func apply_stats_from_resource():
	if not stats: return
	
	mass = stats.mass
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = stats.bounce
	physics_material_override.friction = stats.grip
	
	if grip_component:
		grip_component.grip_strength = stats.grip
		
	if armor_component && stats.armor:
		armor_component.armor = stats.armor
		
	jump_strength = stats.jump_force

	print("Player stats have been reapplied. New Grip value: ", stats.grip)

# Loads a new ability scene into one of the designated slots.
func equip_ability(ability_info: AbilityInfo, slot_number: int):
	var target_slot = ability1_slot if slot_number == 1 else ability2_slot
	if not target_slot: return

	# 1. Check for and disconnect any OLD ability in the slot.
	if target_slot.get_child_count() > 0:
		var old_ability = target_slot.get_child(0)
		if old_ability.cooldown_updated.is_connected(_on_ability1_cooldown_updated):
			old_ability.cooldown_updated.disconnect(_on_ability1_cooldown_updated)
		if old_ability.cooldown_updated.is_connected(_on_ability2_cooldown_updated):
			old_ability.cooldown_updated.disconnect(_on_ability2_cooldown_updated)
		old_ability.queue_free()

	# 2. Handle equipping a NEW ability.
	if ability_info and ability_info.ability_scene:
		var new_ability = ability_info.ability_scene.instantiate()
		target_slot.add_child(new_ability)
		print("Equipped ", new_ability.name, " in slot ", slot_number)

		# 3. Connect signals for the new ability based on the slot.
		if slot_number == 1:
			# Connect the ability's signal to our NEW handler function.
			new_ability.cooldown_updated.connect(_on_ability1_cooldown_updated)
			GameManager.ability1_equipped.emit(ability_info)
			# Immediately update the HUD to show it's ready.
			GameManager.ability1_cooldown_updated.emit(0.0)
		else: # slot_number == 2
			new_ability.cooldown_updated.connect(_on_ability2_cooldown_updated)
			GameManager.ability2_equipped.emit(ability_info)
			GameManager.ability2_cooldown_updated.emit(0.0)
	
	# 4. Handle UNEQUIPPING (if ability_info is null).
	else:
		print("Unequipped ability in slot ", slot_number)
		if slot_number == 1:
			GameManager.ability1_equipped.emit(null)
			GameManager.ability1_cooldown_updated.emit(0.0)
		else: # slot_number == 2
			GameManager.ability2_equipped.emit(null)
			GameManager.ability2_cooldown_updated.emit(0.0)

# This function handles the smooth blending between our three collision shapes
# based on the player's current speed. It is called every physics frame.
func update_collision_shapes(current_speed: float):

	# --- STAGE 1: Blending from Detailed Polygon to Smooth Capsule ---
	
	# `smoothstep` is a mathematical function that creates a smooth S-curve interpolation.
	# It takes a value (`current_speed`) and maps it to a 0.0-1.0 range based on a min and max.
	# It's better than `lerp` for this because it eases in and out, preventing abrupt changes.
	# `t_poly_to_capsule` will be 0.0 at low speed and 1.0 at mid speed.
	var t_poly_to_capsule = smoothstep(low_speed_threshold, mid_speed_threshold, current_speed)
	
	# We want the polygon to shrink as `t_poly_to_capsule` grows.
	# `1.0 - t` gives us an inverted factor.
	var poly_scale = 1.0 - t_poly_to_capsule
	
	# We must create a new PackedVector2Array. Modifying the original in-place can be buggy.
	var scaled_poly = PackedVector2Array()
	# We loop through the original, full-size polygon points we saved in _ready().
	for point in original_polygon_points:
		# We scale each point towards the origin (0,0) and add it to our new array.
		scaled_poly.append(point * poly_scale)
	# Finally, we assign the new, smaller set of points to the polygon shape.
	collision_polygon.polygon = scaled_poly
	# To save performance, we completely disable the polygon shape when it's nearly invisible.
	collision_polygon.disabled = (poly_scale < 0.01)
	
	# Simultaneously, we grow the capsule IN using the same interpolation factor 't'.
	# `lerp` (linear interpolation) blends between a start and end value.
	# Height goes from 0 to its target height. Radius goes from nearly-zero to its target.
	collision_capsule.shape.height = lerp(0.0, target_capsule_height, t_poly_to_capsule)
	collision_capsule.shape.radius = lerp(0.01, target_capsule_radius, t_poly_to_capsule)
	
	
	# --- STAGE 2: Blending from Smooth Capsule to Perfect Circle ---
	
	# We do the same thing again for the next speed range. `t_capsule_to_circle`
	# will be 0.0 at mid speed and 1.0 at high speed.
	var t_capsule_to_circle = smoothstep(mid_speed_threshold, high_speed_threshold, current_speed)
	
	# This time, we want the capsule to shrink OUT as speed increases.
	var capsule_scale = 1.0 - t_capsule_to_circle
	# We scale both its height and radius down towards zero based on this inverted factor.
	collision_capsule.shape.height = target_capsule_height * capsule_scale
	collision_capsule.shape.radius = target_capsule_radius * capsule_scale
	collision_capsule.disabled = (capsule_scale < 0.01)
	
	# Simultaneously, we grow the final circle IN. Its radius goes from nearly-zero
	# to its full target size as `t_capsule_to_circle` goes from 0.0 to 1.0.
	collision_circle.shape.radius = lerp(0.01, target_circle_radius, t_capsule_to_circle)
	# We enable the circle shape only when it starts to grow, to be efficient.
	collision_circle.disabled = (t_capsule_to_circle < 0.01)

func _ensure_skin_material_is_unique():
	if _skin_material_made_unique:
		return # Do nothing if we've already done this.
	
	if skin_sprite.material:
		skin_sprite.material = skin_sprite.material.duplicate()
		print("Player: Skin material has been made unique.")
	
	_skin_material_made_unique = true


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
