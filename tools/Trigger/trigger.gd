extends Area2D

# ─── GENERAL SETTINGS ─────────────────
@export_category("General Settings")
@export var trigger_once: bool = false
@export var trigger_only_for_player: bool = true
@export var trigger_for_physics_objects: bool = false
@export var reset_delay: float = 0.0   # Delay (in seconds) before resetting the trigger if trigger_once is false

# ─── BREAKABLE OBJECTS ─────────────────
@export_category("Breakable Objects")
@export_group("Break Settings")
@export var break_shapes: Array[NodePath] = []
@export var break_delays: Array[float] = []  # One delay per breakable object

# ─── SOUND EFFECTS ─────────────────
@export_category("Sound Effects")
@export_group("Sound Settings")
@export var sound_effects: Array[AudioStream] = []
@export var sound_delays: Array[float] = []  # One delay per sound
@export var sound_volumes: Array[float] = []  # Volume in dB for each sound (default 0.0)
@export var sound_pitches: Array[float] = []  # Pitch scale for each sound (default 1.0)
@export var sound_buses: Array[String] = ["Master"]   # Audio bus name for each sound (default "Master")

# ─── ENTITY SPAWNING ─────────────────
@export_category("Entity Spawning")
@export_group("Spawn Settings")
@export var entities_to_spawn: Array[PackedScene] = []
@export var spawn_positions: Array[Vector2] = []  # Optional; if not provided, uses trigger position
@export var spawn_delays: Array[float] = []  # One delay per entity

# ─── IMPULSE APPLICATION ─────────────────
@export_category("Impulse Settings")
@export_group("Force Settings")
@export var impulse_targets: Array[NodePath] = []
@export var impulse_forces: Array[Vector2] = []  # Each vector specifies the impulse (direction & magnitude) for the corresponding target
@export var impulse_delays: Array[float] = []  # One delay per impulse

var triggered: bool = false

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body):
	if triggered and trigger_once:
		return
	
	if trigger_only_for_player and not body.is_in_group("player"):
		return
	if trigger_for_physics_objects and body is RigidBody2D:
		pass
	elif not trigger_for_physics_objects and not body.is_in_group("player"):
		return
	
	triggered = true
	
	_break_shapes_delayed()
	_play_sounds_parallel()
	_spawn_entities_parallel()
	_apply_impulses()
	
	if not trigger_once:
		if reset_delay > 0:
			_create_timer(reset_delay, Callable(self, "_reset_trigger"))
		else:
			triggered = false

func _reset_trigger():
	triggered = false

# ##############################
#   TIMER HELPER FUNCTION
# ##############################
func _create_timer(delay: float, callback: Callable, bind_args: Array = []) -> Timer:
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = delay
	add_child(timer)
	timer.timeout.connect(callback.bindv(bind_args))
	timer.start()
	return timer

# ##############################
#      BREAKABLE OBJECTS
# ##############################
func _break_shapes_delayed():
	for i in range(break_shapes.size()):
		var delay = break_delays[i] if i < break_delays.size() else 0.0
		_create_timer(delay, Callable(self, "_on_break_timer_timeout_with_shape"), [break_shapes[i]])

func _on_break_timer_timeout_with_shape(shape_path: NodePath) -> void:
	var shape = get_node_or_null(shape_path)
	if shape:
		shape.queue_free()

# ##############################
#         SOUND EFFECTS
# ##############################
func _play_sounds_parallel():
	for i in range(sound_effects.size()):
		var sound = sound_effects[i]
		var delay = sound_delays[i] if i < sound_delays.size() else 0.0
		_play_sound_delayed(sound, delay, i)

func _play_sound_delayed(sound: AudioStream, delay: float, index: int):
	_create_timer(delay, Callable(self, "_on_sound_timer_timeout"), [sound, index])

func _on_sound_timer_timeout(sound: AudioStream, index: int) -> void:
	print("Playing sound:", sound)  # Debug print
	var audio_player = AudioStreamPlayer2D.new()
	audio_player.stream = sound
	# Retrieve individual sound settings or use defaults:
	# Volume defaults to 0.0 dB, pitch defaults to 1.0, and bus defaults to "Master"
	var vol: float = 0.0
	if index < sound_volumes.size():
		vol = sound_volumes[index]
	var pitch: float = 1.0
	if index < sound_pitches.size():
		pitch = sound_pitches[index]
	var bus: String = "Master"
	if index < sound_buses.size():
		bus = sound_buses[index]
	audio_player.volume_db = vol
	audio_player.pitch_scale = pitch
	audio_player.bus = bus
	add_child(audio_player)
	audio_player.play()
	audio_player.connect("finished", Callable(audio_player, "queue_free"))

# ##############################
#       ENTITY SPAWNING
# ##############################
func _spawn_entities_parallel():
	for i in range(entities_to_spawn.size()):
		var scene = entities_to_spawn[i]
		var delay = spawn_delays[i] if i < spawn_delays.size() else 0.0
		var position = spawn_positions[i] if i < spawn_positions.size() else global_position
		_spawn_entity_delayed(scene, position, delay)

func _spawn_entity_delayed(scene: PackedScene, position: Vector2, delay: float):
	_create_timer(delay, Callable(self, "_on_spawn_timer_timeout"), [scene, position])

func _on_spawn_timer_timeout(scene: PackedScene, position: Vector2) -> void:
	var instance = scene.instantiate()
	get_parent().add_child(instance)
	instance.global_position = position

# ##############################
#     IMPULSE APPLICATION
# ##############################
func _apply_impulses():
	for i in range(impulse_targets.size()):
		var delay = impulse_delays[i] if i < impulse_delays.size() else 0.0
		_create_timer(delay, Callable(self, "_on_impulse_timer_timeout"), [i])

func _on_impulse_timer_timeout(index: int) -> void:
	var node = get_node_or_null(impulse_targets[index])
	var target: RigidBody2D = null
	if node:
		if node is RigidBody2D:
			target = node
		elif node:
			# Try a child named "PhysicsBody"
			if node.has_node("PhysicsBody"):
				var potential = node.get_node("PhysicsBody")
				if potential is RigidBody2D:
					target = potential
			# Otherwise, search the immediate children for any RigidBody2D
			if not target:
				for child in node.get_children():
					if child is RigidBody2D:
						target = child
						break
	if target:
		if target.sleeping:
			target.sleeping = false
		var force: Vector2 = impulse_forces[index] if index < impulse_forces.size() else Vector2.ZERO
		if force != Vector2.ZERO:
			target.apply_central_impulse(force)
	else:
		push_warning("No valid RigidBody2D found for impulse target at index " + str(index))
