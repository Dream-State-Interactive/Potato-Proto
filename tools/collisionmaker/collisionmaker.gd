@tool
extends Node2D

@export var potato_texture: Texture2D
@export var collision_detail = 4


func _ready():
	# Generate the collision when the node enters the scene tree.
	if potato_texture:
		generate_collision_and_sprite(potato_texture)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if potato_texture:
			# Remove ALL children before generating new ones.
			for child in get_children():
				remove_child(child)
			generate_collision_and_sprite(potato_texture)
			queue_redraw()
	else:
		return

# Function to create the sprite and collision polygon.
func generate_collision_and_sprite(texture: Texture2D):
	# 1. Create a Sprite2D node and assign the texture.
	var sprite = Sprite2D.new()
	sprite.texture = texture


	# 2. Create a RigidBody2D for physics.
	var rigid_body = RigidBody2D.new()
	# Set the RigidBody2D's position to match the sprite.
	rigid_body.position = sprite.position 
	# Add the RigidBody2D to the scene.
	add_child(rigid_body)
	# Make the sprite a child of the RigidBody2D so they move together.
	rigid_body.add_child(sprite)
		
	#Stop in-editor error loop
	if Engine.is_editor_hint():
		if texture.get_image().get_width() > 0:
			return
		
		
	# 3. Get the image data from the texture and convert to RGBA8 format.
	var image = texture.get_image()
	image.convert(Image.FORMAT_RGBA8)  # Ensure correct alpha values.

	var width: float = image.get_width()
	var height: float = image.get_height()


	# 4. Downsample the image for performance.
	var simplification_factor = collision_detail  # Higher value = simpler collision, better performance.
	image.resize(width / simplification_factor, height / simplification_factor, Image.INTERPOLATE_NEAREST)
	width = image.get_width() # Update width and height after resizing.
	height = image.get_height()


	# 5. Extract edge points from the downsampled image.
	var edge_points = PackedVector2Array() # Array to store the edge points.
	for y in range(height):
		for x in range(width):
			# Check if the pixel is mostly opaque (alpha > 0.5).
			if image.get_pixel(x, y).a > 0.5:
				# Check if the pixel is an edge pixel.
				if _is_edge_pixel(image, x, y):
					# Scale the point back up to the original image size.
					edge_points.append(Vector2(x, y) * simplification_factor)


	# 6. Simplify the polygon using the convex hull algorithm (optional).
	var simplified_polygon = _convex_hull(edge_points)


	# 7. Create a CollisionPolygon2D and set its points.
	var collision_polygon = CollisionPolygon2D.new()
	collision_polygon.polygon = simplified_polygon

	# Calculate the offset to center the collision polygon on the sprite.
	var offset = Vector2(image.get_width(), image.get_height()) * simplification_factor / 2
	collision_polygon.position = -offset # Apply the offset

	# Add the collision polygon to the RigidBody2D.
	rigid_body.add_child(collision_polygon)


# Helper function to check if a pixel is an edge.
func _is_edge_pixel(image: Image, x: int, y: int) -> bool:
	# If the pixel is transparent, it's not an edge.
	if image.get_pixel(x, y).a <= 0.5: # 0.5 is the alpha threshold
		return false # Not an edge, because it is fully or mostly transparent

# 2. Check the 8 neighboring pixels (including diagonals).
	for i in range(-1, 2): # Loop from -1 to 1 for x-offset.
		for j in range(-1, 2): # Loop from -1 to 1 for y-offset.
			# Skip checking the pixel itself.
			if i == 0 and j == 0: 
				continue

			# Calculate neighbor coordinates.
			var nx = x + i  # Neighbor's x-coordinate
			var ny = y + j  # Neighbor's y-coordinate

			# Check if neighbor is out of bounds OR transparent.
			if nx < 0 or nx >= image.get_width() or ny < 0 or ny >= image.get_height() or image.get_pixel(nx, ny).a <= 0.5:
				return true  # It's an edge because it has at least one transparent or out-of-bounds neighbor.

	# If all neighbors are opaque, this is not an edge.
	return false



# Helper function to calculate the convex hull of a set of points.
func _convex_hull(points: PackedVector2Array) -> PackedVector2Array:
	# If there are fewer than 3 points, a convex hull cannot be formed.
	if points.size() < 3:
		return points
	# Use Godot's built-in convex hull function.
	return Geometry2D.convex_hull(points)
