# src/abilities/ability_info.gd

class_name AbilityInfo
extends Resource

## The name of the ability to be displayed as the title.
@export var ability_name: String = "New Ability"

## The descriptive text that explains what the ability does.
@export_multiline var ability_description: String = "Ability description goes here."

## The texture that will be used for the icon in the UI.
@export var icon: Texture2D

## A reference to the PackedScene (.tscn file) of the ability itself.
## This is what will be instantiated and given to the player.
@export var ability_scene: PackedScene
