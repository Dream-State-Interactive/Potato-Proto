# =============================================================================
# c_hazard.gd - A Universal Damage and Hazard Identifier
# =============================================================================
#
# WHAT IT IS:
# A simple component that can be attached to ANY object (RigidBody, Area2D, etc.)
# to mark it as hazardous. It also holds the amount of damage it deals.
#
# ARCHITECTURE:
# - It acts as a data container. The Player's collision logic will look for
#   this component on objects it hits to determine if it should take damage.
# - For convenience, if its parent is an Area2D, it automatically connects to the
#   'body_entered' signal to handle trigger-zone style damage.
# - It uses a naming convention ('_hazard' suffix on CollisionShape nodes) to
#   identify which specific parts of a complex object are dangerous.
#
# =============================================================================
class_name CHazard
extends Node

# --- Configuration ---
## The amount of damage this hazard will deal upon a successful hit.
@export var damage: float = 25.0

# --- Internal State ---
# This array stores the unique IDs of the collision shapes on the parent body
# that are marked as dangerous (by ending their name with "_hazard").
var _hazard_owner_ids: Array[int] = []

# --- Godot Functions ---
func _ready():
	# We must get a reference to our parent node to inspect its shapes.
	# We cast it as CollisionObject2D, which is the base class for Area2D,
	# StaticBody2D, RigidBody2D, etc., making this component universal.
	var body = get_parent() as CollisionObject2D
	if not body:
		push_error("CHazard must be a child of a CollisionObject2D!")
		return

	# --- Auto-configure for Area2D ---
	# If the parent is an Area2D, we automatically wire up its signals.
	if body is Area2D:
		if not body.body_entered.is_connected(_on_body_entered):
			body.body_entered.connect(_on_body_entered)
		print("CHazard on '", body.name, "' configured for Area2D.")
	
	# --- Scan for Hazardous Shapes by Name ---
	# This is the core of the multi-shape damage system.
	print("--- CHazard on '", body.name, "' is ready. Scanning shapes... ---")
	# Loop through every shape owner ID on the parent body.
	for owner_id in body.get_shape_owners():
		# For each ID, get the actual CollisionShape2D/CollisionPolygon2D node.
		var shape_node = body.shape_owner_get_owner(owner_id)
		if shape_node:
			print("Found shape '", shape_node.name, "' with owner_id ", owner_id)
			# If the node's name ends with our special suffix, it's dangerous.
			if shape_node.name.ends_with("_hazard"):
				_hazard_owner_ids.append(owner_id)
				print(">> Marked as hazardous!")
	print("Hazardous owner IDs for this object: ", _hazard_owner_ids)

# --- Public API ---
## The Player script calls this function to ask: "Is the part I just hit dangerous?"
func is_hazard_shape(owner_id: int) -> bool:
	# Simply checks if the provided owner_id is in our list of dangerous IDs.
	return owner_id in _hazard_owner_ids

# --- Signal Callbacks ---
# This function ONLY runs if the parent is an Area2D.
func _on_body_entered(body: Node2D):
	# Check if the body that entered can take damage.
	if body.has_method("take_damage_from_hazard"):
		# We pass ourselves (this CHazard data component) to the player.
		body.take_damage_from_hazard(self)
