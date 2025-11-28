# This script makes a RigidBody2D with a Polygon2D child "fracturable."
# When it takes a hard enough hit, it will break apart into smaller pieces.
extends RigidBody2D

# --- EXPORTED VARIABLES ---

# --- GENERAL PHYSICS ---
@export_group("General Physics")
## If enabled, the body will be held stationary until it is broken.
@export var start_stationary: bool = false
## The minimum force of impact required to shatter this object.
@export var min_break_impulse: float = 150.0

# --- SHARD EFFECT ---
@export_group("Shard Effect")
## If enabled, the object will break into smaller physical pieces.
@export var enable_shard_effect: bool = true
## The lifetime of a shard in seconds. If set to 0, shards will not disappear.
@export var shard_lifetime: float = 5.0
## The duration of the fade-out effect in seconds.
@export var shard_fade_duration: float = 1.0
## If enabled, shards will be able to collide with other physics objects.
@export var shards_have_collision: bool = true
# To create a shatter pattern, we add random points inside the polygon.
## This controls how many extra points are added. More points = smaller, more complex shards.
@export var shard_point_count: int = 6
## The maximum number of shards you want to spawn.
# We might generate more triangles than this, so this caps the final count.
@export var desired_shards: int = 10
## When the object shatters, the pieces fly apart. These control the force of that "explosion."
@export var min_impulse: float = 200.0
## When the object shatters, the pieces fly apart. These control the force of that "explosion."
@export var max_impulse: float = 400.0
## Set this to a non-zero number. If it's 0, it will be random each time.
@export var random_seed: int = 0

# --- PARTICLE EFFECT ---
@export_group("Particle Effect")
## If enabled, a particle effect will be spawned at the impact point.
@export var enable_particle_effect: bool = true
## The scale multiplier for the spawned particle effect.
@export var particle_scale: float = 1.0
## The particle scene to instance when the object fractures. This should be a GPUParticles2D or CPUParticles2D node.
# The particle node should be configured to play on its own and ideally destroy itself when finished.
@export var particle_effect: PackedScene

# --- SOUND EFFECT ---
@export_group("Sound Effect")
## If enabled, a sound will play when the object fractures.
@export var enable_sound_effect: bool = true
## The sound to play on fracture. For multiple random sounds, you can use an AudioStreamRandomizer resource.
@export var sound_effect: AudioStream


# --- SIGNALS ---
# Signals are calls that other nodes can listen for.
# We'll "emit" this signal right after the object fractures, in case
# other parts of your game (like a score manager/sound manager) need to know.
signal fractured

# --- NODE REFERENCES ---
# The `@onready` keyword is a safe way to get these references to child nodes.
# It waits until the node is fully loaded into the game world (the "scene tree") before assigning the variable.

# This is the visible, textured polygon that the player sees.
@onready var polygon_2d: Polygon2D = $Polygon2D
# This is the invisible physics shape that Godot uses for collisions.
@onready var collision_2d: CollisionPolygon2D = $CollisionPolygon2D

# --- STATE VARIABLES ---
# These variables track the object's state during gameplay.

# A simple flag to make sure the object only fractures once.
var fractured_once: bool = false
# A random number generator object. We'll use this for all our random calculations.
var rng = RandomNumberGenerator.new()


# The `_ready` function is called by Godot once, when the node first enters the scene.
# This is typically best for one-time setup.
func _ready() -> void:
	# To detect the force of a collision, we must enable the contact monitor.
	contact_monitor = true
	# This is a performance setting. It tells Godot the max number of collisions to report per frame.
	max_contacts_reported = 4
	
	# Set up our random number generator based on the exported variable.
	if random_seed != 0:
		rng.seed = random_seed # Use a fixed seed for predictable results.
	else:
		rng.randomize() # Use a random seed for unpredictable results.


# `_integrate_forces` is a special physics function that runs every physics frame.
# Called during physics processing, allowing you to read and safely modify the simulation state for the object.
# It allows you to directly access the physics state, including collision forces (impulses).
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# If we've already fractured, do nothing.
	if fractured_once:
		return
	
	# If start_stationary is true, we manually hold the body in place every frame.
	# This keeps it active in the physics simulation (so it can detect impulses)
	# but prevents it from moving, effectively making it a static object until it breaks.
	# Using `freeze` is incorrect as it removes the body from impulse calculations.
	if start_stationary:
		state.linear_velocity = Vector2.ZERO
		state.angular_velocity = 0.0
	
	# Loop through all the points where this body is touching another one in this frame.
	for i in range(state.get_contact_count()):
		# Get the impulse (the force of the impact) at this contact point.
		var imp_vec = state.get_contact_impulse(i)
		
		# Check if the force of the impact is strong enough to break the object.
		if imp_vec.length() >= min_break_impulse:
			# It's strong enough! UwU | Set the flag so we don't break again.
			fractured_once = true
			
			# If we were holding the body stationary, we now stop.
			# The `start_stationary` variable will now evaluate to false in the next frame's check.
			start_stationary = false
				
			# Get the position of the impact, in our own local coordinates.
			var impact_pos = state.get_contact_local_position(i)
			# Call the main function to handle the shattering logic.
			_fracture(impact_pos)
			# Stop checking for more contacts; we're already broken *hairflip.
			return


# This is the main function where chicka-migunga's.
# It calculates the shard shapes and tells the game to spawn them.
func _fracture(impact_point: Vector2) -> void:
	
	# =============================================================================
	# STEP -1: PLAY ON-BREAK EFFECTS
	# =============================================================================
	# WHY: Sound and particle effects should trigger the moment the object breaks,
	# regardless of whether physical shards are spawned. We handle these first.
	#
	# HOW: We check the exported booleans and spawn the relevant nodes if they are set.
	
	# Play the particle effect if it's enabled and a valid scene is assigned.
	if enable_particle_effect and particle_effect:
		var particles = particle_effect.instantiate()
		# We need to make sure it's a Node2D to be able to set its properties.
		if particles is Node2D:
			get_tree().current_scene.add_child(particles)
			# Set the particle's position to this object's center (its global_position)
			# instead of the impact point. This ensures the effect is always centered on the object.
			particles.global_position = self.global_position
			# Apply the custom scale to the particle effect.
			particles.scale = Vector2(particle_scale, particle_scale)
			# For particle emitters (like GPUParticles2D), we need to start them.
			# This is a safe way to call 'set_emitting' without causing an error if the node doesn't have it.
			if particles.has_method("set_emitting"):
				particles.set_emitting(true)

	# Play the sound effect if it's enabled and a valid stream is assigned.
	if enable_sound_effect and sound_effect:
		# We create a temporary player node to play our sound.
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = sound_effect
		# Add it to the scene, play it, and make it clean itself up when finished.
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(audio_player.queue_free)

	# If the shard effect is disabled, we can stop here after playing other effects.
	if not enable_shard_effect:
		queue_free()
		emit_signal("fractured")
		return # Exit the function early.
	
	# =============================================================================
	# STEP 0: ESTABLISH GROUND TRUTH - GETTING THE *REAL* VERTEX POSITIONS
	# =============================================================================
	# WHY: In Godot, a Polygon2D's visual appearance is a combination of its
	# raw `polygon` data (a list of points) AND its `offset` property. The
	# `polygon` data itself is often relative to (0,0). The `offset` moves
	# the whole shape. If we only use `polygon_2d.polygon`, our calculations
	# for shape and texture will be based on the wrong positions.
	#
	# HOW: We must manually combine the raw polygon data with the offset to get
	# a list of vertices that represents what the player actually sees. This
	# `base_poly` array becomes our "source of truth" for all subsequent steps.
	var poly_node_offset = polygon_2d.offset
	var base_poly_raw = polygon_2d.polygon
	
	var base_poly: PackedVector2Array = []
	for v in base_poly_raw:
		base_poly.append(v + poly_node_offset)


	# =============================================================================
	# STEP 1: DESIGN THE SHATTER PATTERN - BUILD A LIST OF "SEED" POINTS
	# =============================================================================
	# WHY: To create a convincing shatter, we use a powerful geometry algorithm
	# called Delaunay Triangulation. Think of it as a "connect-the-dots" machine
	# that creates a mesh of triangles from a list of points. The points we feed it
	# (the "seeds") will define the final look of the fracture.
	#
	# HOW: We create a list of seed points that includes:
	#   1. The original polygon's corners: This ensures the shards respect the original outline.
	#   2. New random points inside the polygon: This creates the chaotic, fractured interior.
	var seeds = base_poly.duplicate() # Start with the original shape's corners.
	
	# To generate random points *inside* the shape, we first find its bounding box.
	var bounds = Rect2(base_poly[0], Vector2.ZERO)
	for v in base_poly:
		bounds = bounds.expand(v)

	# Now, sprinkle our random seed points inside the shape.
	for _i in shard_point_count:
		while true: # Loop until we find a valid point.
			# Pick a random point within the simple rectangular bounds.
			var p = Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			
			# IMPORTANT: The point might be in the bounding box but outside our actual
			# (potentially concave) polygon shape. We must check for this.
			if Geometry2D.is_point_in_polygon(p, base_poly):
				seeds.append(p)
				break # The point is valid, so we keep it and break the loop.


	# =============================================================================
	# STEP 2: GENERATE THE SHARDS - TRIANGULATION AND FILTERING
	# =============================================================================
	# WHY: The Delaunay algorithm is very robust, but it can sometimes generate
	# triangles that fill in concave areas or sit slightly outside our original polygon.
	# We need to filter its output to ensure every shard we create was truly part
	# of the original shape.
	#
	# HOW: We call Godot's built-in triangulation function, then loop through the
	# resulting triangles and keep only the ones whose center point is inside our
	# "ground truth" `base_poly`.
	var idxs = Geometry2D.triangulate_delaunay(seeds) # This returns a list of indices into our `seeds` array.
	
	var tris: Array = [] # This will hold our final, valid shard shapes.
	# Loop through the indices, 3 at a time, to form each triangle.
	for j in range(0, idxs.size(), 3):
		var v0 = seeds[idxs[j]]
		var v1 = seeds[idxs[j+1]]
		var v2 = seeds[idxs[j+2]]
		
		# The filter: check if the triangle's center is inside the original polygon.
		var cen = (v0 + v1 + v2) / 3.0 # Calculate the center point (centroid).
		if Geometry2D.is_point_in_polygon(cen, base_poly):
			tris.append([v0, v1, v2]) # This is a valid shard, add it to our list.

	# Shuffling makes the spawned shards appear in a more random, natural order,
	# especially if we aren't spawning all of the generated triangles.
	tris.shuffle()


	# =============================================================================
	# STEP 3: CREATE THE SHARD OBJECTS IN THE GAME
	# =============================================================================
	# WHY: We now have a list of all possible shard shapes. This step takes that
	# abstract data and turns it into actual `RigidBody2D` nodes in our game.
	#
	# HOW: We loop a controlled number of times and call our helper function,
	# `_spawn_shard`, for each piece we want to create.
	var spawn_count = min(desired_shards, tris.size())
	for i in range(spawn_count):
		# Pass the vertex data for one shard and the impact point to the spawner function.
		_spawn_shard(tris[i], impact_point)


	# =============================================================================
	# STEP 4: CLEANUP
	# =============================================================================
	# WHY: The original, unbroken object should no longer exist. We need to
	# remove it from the game world. Using `queue_free()` is the only safe way to
	# delete a node that is active in the physics engine. It waits until the end
	# of the current frame to perform the deletion, preventing crashes.
	#
	# HOW: We call `queue_free()` on ourself and emit our "fractured" signal
	# to let any other part of the game know that this object has been destroyed.
	queue_free()
	emit_signal("fractured")

# This function creates a single shard piece. It's called repeatedly by `_fracture` to create each piece of debris.
# It takes the vertices that define the shard's shape (`verts`) and the original point of impact (`impact_point`).
func _spawn_shard(verts: PackedVector2Array, impact_point: Vector2) -> void:

	# =============================================================================
	# STEP 1: POSITIONING THE SHARD - FIND THE CENTER
	# =============================================================================
	# WHY: Every node in Godot has a position (its origin). For a complex shape
	# like our shard, the most intuitive origin is its geometric center, or "centroid."
	# We need to calculate this center point first, as everything else will be
	# relative to it. The `verts` we receive are in the *parent's* coordinate system.
	#
	# HOW: We average the positions of all the shard's vertices to find the centroid.
	# Then, we convert this local position into a global, world-space position, which
	# is where we will place our new RigidBody2D node.
	var cen := Vector2.ZERO
	for v in verts: cen += v
	cen /= verts.size()
	
	# `to_global()` is a crucial helper that translates a point from this node's
	# local coordinate space into the main scene's world coordinate space.
	var world_cen = to_global(cen)


	# =============================================================================
	# STEP 2: CREATING THE SHARD'S "BODY"
	# =============================================================================
	# WHY: Each shard needs to be an independent physics object that can fly around,
	# collide, and react to gravity. The `RigidBody2D` node is Godot's built-in
	# solution for this.
	#
	# HOW: We create a new `RigidBody2D` instance in code, set its position,
	# configure its collision properties, and add it to the scene so it becomes active.
	var shard = RigidBody2D.new()
	shard.position = world_cen
	
	# If shard collision is disabled, we remove the body from all physics layers
	# by setting its layer and mask to 0. This is the most reliable method.
	if not shards_have_collision:
		shard.collision_layer = 0
		shard.collision_mask = 0
		
	get_tree().current_scene.add_child(shard)


	# =============================================================================
	# STEP 3: DEFINING THE SHARD'S LOCAL SHAPE
	# =============================================================================
	# WHY: The shard's `Polygon2D` and `CollisionPolygon2D` nodes need to know their
	# shape. Critically, their vertex data must be *relative to their parent's origin*.
	# Since we placed the parent `RigidBody2D` at the centroid, the centroid now
	# effectively becomes the local (0,0) point for this shard.
	#
	# HOW: We create a new list of points (`local_pts`) by subtracting the
	# centroid's position from each of the original vertex positions. This recenters
	# the shape around (0,0).
	var local_pts := PackedVector2Array()
	for v in verts:
		local_pts.append(v - cen)


	# =============================================================================
	# STEP 4: GIVING THE SHARD A VISUAL APPEARANCE
	# =============================================================================
	# WHY: The `RigidBody2D` is just a physics controller. To make it visible, it needs
	# a child node that can be rendered, like a `Sprite2D` or, in our case, a `Polygon2D`.
	#
	# HOW: We create a `Polygon2D` node, give it the `local_pts` we just calculated
	# to define its shape, and copy the texture, color, and repeat properties from
	# the original object to ensure it looks the same.
	var poly2d = Polygon2D.new()
	poly2d.polygon = local_pts
	poly2d.texture = polygon_2d.texture
	poly2d.color = polygon_2d.color
	poly2d.texture_repeat = polygon_2d.texture_repeat
	shard.add_child(poly2d)


	# =============================================================================
	# STEP 5: THE MAGIC - TEXTURE COORDINATE (UV) MAPPING
	# =============================================================================
	# WHY: This is the most complex and critical part for getting the texture right.
	# By default, the new `poly2d` has no idea which part of the texture it should show.
	# We need to tell it, for each of its vertices, "you correspond to *this exact pixel*
	# on the original texture." This is done by setting the `uv` property.
	#
	# THE GODOT SECRET: Manually setting `Polygon2D.uv` requires coordinates in PIXEL SPACE
	# (Vector2(250, 120)) or (0 to texture_width), not normalized space (Vector2(0.5, 0.25)) or (0.0 to 1.0).
	#
	# HOW: We loop through the original `verts` (which are in the correct coordinate
	# space for this calculation) and apply the *exact same* texture transform
	# (offset, rotation, scale) that the original `Polygon2D` was using. This "forward transform"
	# calculates the final pixel coordinate on the texture for each vertex.
	var tex = polygon_2d.texture
	if tex:
		var texture_offset = polygon_2d.texture_offset
		var texture_rotation = polygon_2d.texture_rotation
		var texture_scale_uv = polygon_2d.texture_scale

		var uvs := PackedVector2Array()
		for v in verts:
			var uv = v
			# THE FORMULA: uv_pixel = (vertex_local - texture_offset).rotated(texture_rotation) * texture_scale
			uv -= texture_offset      # 1. Shift vertex relative to the texture's origin.
			uv = uv.rotated(texture_rotation) # 2. Rotate it around that new origin.
			uv *= texture_scale_uv    # 3. Scale it.
			uvs.append(uv)
		
		# We assign the final array of pixel coordinates. Godot's renderer now knows
		# exactly how to map the texture onto this shard.
		poly2d.uv = uvs


	# =============================================================================
	# STEP 6: GIVING THE SHARD A PHYSICAL PRESENCE
	# =============================================================================
	# WHY: A `RigidBody2D` needs a `CollisionShape2D` (or `CollisionPolygon2D`) child
	# to define its physical boundaries for the physics engine. Without this, it's a ghost.
	#
	# HOW: We create a `CollisionPolygon2D`, give it the same `local_pts` as the
	# visual `Polygon2D`. The actual collision is handled by the parent body's layer and mask.
	var colpoly = CollisionPolygon2D.new()
	colpoly.polygon = local_pts
	shard.call_deferred("add_child", colpoly)


	# =============================================================================
	# STEP 7: MAKING IT GO "BOOM!"
	# =============================================================================
	# WHY: A fracture isn't very exciting if the pieces just fall straight down.
	# We need to apply an initial force to make them scatter outwards from the impact.
	#
	# HOW: We calculate a direction vector pointing from the `impact_point` to the
	# shard's center. We then apply an "impulse" (an instant force) along that
	# direction, with a randomized magnitude, to send the shard flying.
	var dir = (cen - impact_point).normalized()
	var mag = rng.randf_range(min_impulse, max_impulse)
	shard.apply_central_impulse(dir * mag)

	# =============================================================================
	# STEP 8: SETTING A LIFETIME AND FADE-OUT
	# =============================================================================
	# WHY: To prevent the scene from getting cluttered, we make shards disappear.
	# A fade-out is visually smoother than instant removal.
	#
	# HOW: We use a Tween, which animates node properties over time. We tell it to:
	#   1. Wait for `shard_lifetime` seconds.
	#   2. Animate the Polygon2D's `color` property, fading its alpha to 0.
	#   3. After the fade, call `queue_free` to safely delete the shard.
	if shard_lifetime > 0.0:
		# Create a tween to handle the fading and delayed deletion.
		# We bind it to the shard so if the shard is destroyed early, the tween stops.
		var tween = get_tree().create_tween().bind_node(shard)
		
		# 1. First, wait for the shard's lifetime to pass before starting the fade.
		tween.tween_interval(shard_lifetime)
		
		# 2. Then, tween the 'color' property of the Polygon2D.
		# Fading its alpha channel (the 'a' component) to 0 makes it transparent.
		var transparent_color = poly2d.color
		transparent_color.a = 0.0
		tween.tween_property(poly2d, "color", transparent_color, shard_fade_duration)
		
		# 3. Finally, after the fade is complete, queue the shard for deletion.
		tween.tween_callback(shard.queue_free)
