class_name CArmor
extends Node

signal armor_changed(current_armor)

@export var armor: float = 0:
	set(value):
		armor = value
		armor_changed.emit(armor)
	get:
		return armor
