# src/core/theme_manager.gd
extends Node

var themes: Array[Dictionary] = [
	{"hill_color": Color.DARK_GREEN, "sky_color": Color.SKY_BLUE},
	{"hill_color": Color.DARK_SLATE_GRAY, "sky_color": Color.DARK_ORCHID},
	{"hill_color": Color.SADDLE_BROWN, "sky_color": Color.DEEP_SKY_BLUE},
	{"hill_color": Color("#5D432C"), "sky_color": Color("#F5D7A3")}, # Pale Yellow
	{"hill_color": Color("#4B0082"), "sky_color": Color("#191970")}, # Indigo
	{"hill_color": Color.ANTIQUE_WHITE, "sky_color": Color.CORAL}, # Pale Yellow
	{"hill_color": Color.HONEYDEW, "sky_color": Color.BLACK}, # Indigo
	{"hill_color": Color.BLACK, "sky_color": Color.AZURE}, # Indigo
]

var current_theme_index: int = 0

func get_current_theme() -> Dictionary:
	return themes[current_theme_index]

func advance_theme():
	current_theme_index = (current_theme_index + 1) % themes.size()
