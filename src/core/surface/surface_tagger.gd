# src/components/surface_tagger.gd
@tool
class_name SurfaceTagger
extends Node

## The definition to apply to the parent.
@export var definition: SurfaceDefinition:
	set(v):
		definition = v
		if Engine.is_editor_hint():
			_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	var parent = get_parent()
	if not parent or not definition:
		return

	# 1. Apply Physics Material (Visual feedback in editor)
	if parent is CollisionObject2D and definition.physics_material:
		parent.physics_material_override = definition.physics_material
	
	# 2. Set Metadata (The "Magic" Link)
	# This embeds the resource reference directly into the parent object
	parent.set_meta(SurfaceManager.META_KEY, definition)
