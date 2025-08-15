# res://LanguageTester.gd
extends Node

func _unhandled_input(event):
	# Press F1 for English
	if Input.is_action_just_pressed("ui_page_up"):
		print("LANGUAGE -> English")
		TranslationServer.set_locale("en")

	# Press F2 for Spanish
	if Input.is_action_just_pressed("ui_page_down"):
		print("LANGUAGE -> Spanish")
		TranslationServer.set_locale("es")
		
	# Press F3 for French
	if Input.is_action_just_pressed("ui_home"):
		print("LANGUAGE -> French")
		TranslationServer.set_locale("fr")
		
	# Press F4 for German
	if Input.is_action_just_pressed("ui_end"):
		print("LANGUAGE -> German")
		TranslationServer.set_locale("de")

	# Press '5' for Japanese
	if Input.is_action_just_pressed("switch_lang_ja"):
		print("LANGUAGE -> Japanese")
		TranslationServer.set_locale("ja")
