extends Node

@export var impact_threshold: float = 300.0

func _physics_process(delta: float) -> void:
	# Process all nodes in the "breakable" group.
	for node in get_tree().get_nodes_in_group("breakable"):
		if node is RigidBody2D:
			var speed: float = node.linear_velocity.length()
			# Debug: print the node's speed.
			print("DEBUG: Breakable node [", node.name, "] speed:", speed)
			if speed >= impact_threshold:
				print("DEBUG: Breaking node [", node.name, "] at speed:", speed)
				_break_object(node)

func _break_object(node: Node) -> void:
	# Retrieve the collision polygon and texture from the node's children.
	var collision_polygon: PackedVector2Array = PackedVector2Array()
	var texture: Texture2D = null
	var sprite: Sprite2D = null

	for child in node.get_children():
		if child is CollisionPolygon2D:
			collision_polygon = child.polygon
		elif child is Sprite2D:
			sprite = child
			texture = child.texture
			print("DEBUG: Original Sprite Centered:", sprite.centered) # Debug: Check Sprite Centered property

	print("DEBUG: _break_object - Texture retrieved:", texture)
	print("DEBUG: Collision polygon size:", collision_polygon.size())

	if collision_polygon.size() < 3:
		print("DEBUG: Not enough vertices for slicing. Removing node.")
		node.queue_free()
		return

	# For testing, force a horizontal slice through the object's center.
	var slice_line = {
		"start": node.global_position - Vector2(50, 0),
		"end":   node.global_position + Vector2(50, 0)
	}
	print("DEBUG: Calculated slice line:", slice_line)

	# Slice the polygon into pieces.
	var pieces = _slice_polygon(collision_polygon, slice_line)
	print("DEBUG: Number of sliced pieces:", pieces.size())

	if pieces.size() == 0:
		print("DEBUG: Slicing did not produce any pieces for [", node.name, "]. Removing node.")
		node.queue_free()
		return

	# Create a new piece for each valid polygon.
	for piece_polygon in pieces:
		print("DEBUG: Piece polygon size:", piece_polygon.size())
		if piece_polygon.size() >= 3:
			_create_piece(node, piece_polygon, texture, sprite)
		else:
			print("DEBUG: Discarding piece with < 3 vertices.")

	print("DEBUG: Finished breaking node [", node.name, "]. Removing original node.")
	node.queue_free()

func _slice_polygon(poly: PackedVector2Array, slice_line: Dictionary) -> Array:
	var a: Vector2 = slice_line["start"]
	var b: Vector2 = slice_line["end"]
	var left_points: Array = []
	var right_points: Array = []
	var count: int = poly.size()

	for i in range(count):
		var current: Vector2 = poly[i]
		var nxt: Vector2 = poly[(i + 1) % count]

		var current_side: bool = _is_left(current, a, b)
		var next_side: bool = _is_left(nxt, a, b)

		if current_side:
			left_points.append(current)
		else:
			right_points.append(current)

		# If the edge crosses the line, compute the intersection.
		if current_side != next_side:
			var inter = _get_intersection(a, b, current, nxt)
			if inter != null:
				left_points.append(inter)
				right_points.append(inter)

	var left_poly = PackedVector2Array(left_points)
	var right_poly = PackedVector2Array(right_points)
	var result = []
	if left_poly.size() >= 3:
		result.append(left_poly)
	if right_poly.size() >= 3:
		result.append(right_poly)
	return result

func _is_left(point: Vector2, a: Vector2, b: Vector2) -> bool:
	# Returns true if point is to the left of the line from a to b.
	return (b - a).cross(point - a) > 0.0

func _get_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2):
	var ad: Vector2 = b - a
	var cd: Vector2 = d - c
	var cross_ad_cd: float = ad.cross(cd)
	if abs(cross_ad_cd) < 0.000001:
		return null

	var ac: Vector2 = c - a
	var t: float = ac.cross(cd) / cross_ad_cd
	var intersection: Vector2 = a + ad * t

	var u: float = ac.cross(ad) / cross_ad_cd
	if u < 0.0 or u > 1.0:
		return null

	return intersection

func _create_piece(original_node: Node, piece_polygon: PackedVector2Array, texture: Texture2D, sprite: Sprite2D) -> void:
	# Create a new RigidBody2D for the piece.
	var piece_body = RigidBody2D.new()
	piece_body.global_position = original_node.global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5)) # Add small random offset
	# **IMPORTANT:** Only add the piece_body to the *scene* - not as child of the script node
	get_tree().current_scene.add_child(piece_body) # Add to scene

	# Add a CollisionPolygon2D for physics.
	var collision = CollisionPolygon2D.new()
	collision.polygon = piece_polygon
	piece_body.add_child(collision)

	# Bake a masked texture and create a Sprite2D for the piece.
	# Bake a masked texture and create a Sprite2D for the piece.
	if texture and sprite:
		var masked_texture = _bake_masked_texture(piece_polygon, sprite)
		var piece_sprite = Sprite2D.new()
		piece_sprite.texture = masked_texture
		piece_sprite.centered = sprite.centered
		piece_sprite.z_index = 10000

		# These lines were invalid and are now removed:
		# new_tex.filter = Texture2D.FILTER_NEAREST
		# new_tex.repeat = Texture2D.REPEAT_DISABLE

		piece_body.add_child(piece_sprite)


# This function bakes a new texture that is masked to the piece_polygon.
func _bake_masked_texture(piece_polygon: PackedVector2Array, sprite: Sprite2D) -> Texture2D:
	print("DEBUG _bake_masked_texture: START")

	var original_texture: Texture2D = sprite.texture
	var original_img: Image = original_texture.get_image()
	original_img.convert(Image.FORMAT_RGBA8)

	var width = original_img.get_width()
	var height = original_img.get_height()
	print("DEBUG: Texture width:", width, "height:", height)

	var new_img: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	new_img.fill(Color(0, 0, 0, 0))

	var sprite_transform = sprite.global_transform
	var local_polygon = []
	var polygon_bounds = Rect2()

	for i in range(piece_polygon.size()):
		var v = piece_polygon[i]
		var local_point = sprite_transform.affine_inverse().basis_xform(v)
		local_polygon.append(local_point)

		if i == 0:
			polygon_bounds.position = local_point
			polygon_bounds.size = Vector2.ZERO
		else:
			polygon_bounds = polygon_bounds.expand(local_point)

	var normalized_polygon = []
	if polygon_bounds.get_area() > 0:
		for local_v in local_polygon:
			var normalized_v = (local_v - polygon_bounds.position) / polygon_bounds.size
			normalized_polygon.append(normalized_v)
	else:
		normalized_polygon = local_polygon

	var texture_pixel_polygon = []
	for normalized_v in normalized_polygon:
		var pixel_v = normalized_v * original_texture.get_size()
		texture_pixel_polygon.append(pixel_v)

	var texture_poly = PackedVector2Array(texture_pixel_polygon)

	for y in range(height):
		for x in range(width):
			var pixel_pos = Vector2(x, y)
			if sprite.centered:
				pixel_pos -= original_texture.get_size() * 0.5

			if Geometry2D.is_point_in_polygon(pixel_pos, texture_poly):
				var col = original_img.get_pixel(x, y)
				new_img.set_pixel(x, y, col)

	# ✅ Create and configure the texture
	var new_tex := ImageTexture.create_from_image(new_img)
	new_tex.set_filter(false)  # Disable filtering (nearest-neighbor)
	new_tex.set_repeat(false)  # Disable tiling/repeat

	print("DEBUG _bake_masked_texture: END")
	return new_tex
