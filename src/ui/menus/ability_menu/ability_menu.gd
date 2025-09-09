# =============================================================================
# src/ui/menus/ability_menu/ability_menu.gd
# =============================================================================
#
# WHAT IT IS:
# This is the central script that manages the entire Ability Store screen.
# It populates the grid with available abilities, listens for hover events
# to update the description panel, and connects the Q/E slot signals to the
# actual player's equip logic.
#
# ARCHITECTURE:
# - It holds an array of AbilityInfo, which defines what's for sale.
# - It dynamically creates AbilityIcon instances based on this data array.
# - It acts as the central hub, connecting signals from icons and slots to
#   the appropriate functions (updating text, telling the player to equip).
#
# =============================================================================
extends CanvasLayer

# --- Node References ---
@onready var grid_container: GridContainer = $Container/VBoxContainer/GridContainer
@onready var ability_title_label: Label = $Container/VBoxContainer/HBoxContainer/AbilityDetail/AbilityTitle
@onready var ability_desc_label: RichTextLabel = $Container/VBoxContainer/HBoxContainer/AbilityDetail/AbilityDescriptionLabel
@onready var q_slot: AbilitySlot = $Container/ColorRect/Q_Slot
@onready var e_slot: AbilitySlot = $Container/ColorRect2/E_Slot

# --- Configuration ---
## Preload the icon scene for easy instantiation.
const ABILITY_ICON = preload("res://src/abilities/ability_icon.tscn")
## Assign your created AbilityInfo files here in the Inspector.
@export var available_abilities: Array[AbilityInfo]

const DEFAULT_TITLE = "ABILITY TITLE"
const DEFAULT_DESCRIPTION = "This is the description for the very potato and roll-based abilities our unsung protagonist \"Potato\" can utilize in their Odyssey-like adventure across hills & tribulations in order to fight against the malignant machinations of Big Aggro."


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Set initial text for the description panel.
	_clear_description_panel()
	
	# Populate the grid with all available abilities.
	for resource in available_abilities:
		var icon = ABILITY_ICON.instantiate() as AbilityIcon
		grid_container.add_child(icon)
		icon.set_ability(resource)
		
		# Connect the icon's hover signals to our handler functions.
		icon.hovered.connect(_on_any_icon_hovered)
		icon.unhovered.connect(_on_any_icon_unhovered)
		
	# Connect the assignment and hover signals from the Q and E slots.
	q_slot.ability_assigned.connect(_on_q_ability_assigned)
	e_slot.ability_assigned.connect(_on_e_ability_assigned)
	
	q_slot.hovered.connect(_on_any_icon_hovered)
	q_slot.unhovered.connect(_on_any_icon_unhovered)
	e_slot.hovered.connect(_on_any_icon_hovered)
	e_slot.unhovered.connect(_on_any_icon_unhovered)


func _input(event: InputEvent):
	if event.is_action_pressed("ability_menu"):
		# We call the function on the global GUI manager to handle the logic.
		GUI.toggle_ability_menu()
		# Stop the input from propagating further.
		get_viewport().set_input_as_handled()

## Called when an ability is dropped on the 'Q' slot.
func _on_q_ability_assigned(resource: AbilityInfo):
	print("Assigning ", resource.ability_name, " to slot 1 (Q)")
	# Use the GameManager to safely access the player instance.
	if GameManager.is_player_active():
		GameManager.player_instance.equip_ability(resource.ability_scene, 1)

## Called when an ability is dropped on the 'E' slot.
func _on_e_ability_assigned(resource: AbilityInfo):
	print("Assigning ", resource.ability_name, " to slot 2 (E)")
	if GameManager.is_player_active():
		GameManager.player_instance.equip_ability(resource.ability_scene, 2)

## Called when the mouse enters ANY ability icon or slot.
func _on_any_icon_hovered(resource: AbilityInfo):
	ability_title_label.text = resource.ability_name.to_upper()
	ability_desc_label.text = resource.ability_description

## Called when the mouse leaves ANY ability icon or slot.
func _on_any_icon_unhovered():
	#_clear_description_panel()
	pass


## Resets the description panel to its default state.
func _clear_description_panel():
	ability_title_label.text = DEFAULT_TITLE
	ability_desc_label.text = DEFAULT_DESCRIPTION


func _on_mouse_entered() -> void:
	pass # Replace with function body.


func _on_mouse_exited() -> void:
	pass # Replace with function body.
