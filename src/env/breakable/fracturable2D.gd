# This script makes a RigidBody2D with a Polygon2D child "fracturable."
# When it takes a hard enough hit, it will break apart into smaller pieces.
extends RigidBody2D

# --- EXPORTED VARIABLES ---

## The minimum force of impact required to shatter this object.
@export var min_break_impulse: float = 150.0

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
	
	# Loop through all the points where this body is touching another one in this frame.
	for i in range(state.get_contact_count()):
		# Get the impulse (the force of the impact) at this contact point.
		var imp_vec = state.get_contact_impulse(i)
		
		# Check if the force of the impact is strong enough to break the object.
		if imp_vec.length() >= min_break_impulse:
			# It's strong enough! UwU | Set the flag so we don't break again.
			fractured_once = true
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
	# HOW: We create a new `RigidBody2D` instance in code, set its position in the
	# world to the centroid we just calculated, and add it to the scene so it becomes active.
	var shard = RigidBody2D.new()
	shard.position = world_cen
	get_parent().add_child(shard)


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
		var offset = polygon_2d.texture_offset
		var rotation = polygon_2d.texture_rotation
		var scale_uv = polygon_2d.texture_scale

		var uvs := PackedVector2Array()
		for v in verts:
			var uv = v
			# THE FORMULA: uv_pixel = (vertex_local - texture_offset).rotated(texture_rotation) * texture_scale
			uv -= offset      # 1. Shift vertex relative to the texture's origin.
			uv = uv.rotated(rotation) # 2. Rotate it around that new origin.
			uv *= scale_uv    # 3. Scale it.
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
	# visual `Polygon2D` so the physics shape perfectly matches the visual shape,
	# and add it as a child to the shard.
	var colpoly = CollisionPolygon2D.new()
	colpoly.polygon = local_pts
	shard.add_child(colpoly)


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
