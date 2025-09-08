# src/dialogue/DialogueResource.gd
@tool
class_name DialogueResource
extends Resource

## A conversation is an array of these lines.
@export var lines: Array[DialogueLine]
