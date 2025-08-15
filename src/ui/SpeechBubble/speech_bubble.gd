# src/ui/SpeechBubble/speech_bubble.gd
@tool
class_name SpeechBubble
extends Control

@onready var bubble_bg: NinePatchRect = $BubbleBG
@onready var bubble_text: RichTextLabel = $BubbleBG/BubbleText
@onready var animator: CGuiScale = $CGUIScale

signal finished

const TEXT_SPEED_CPS = 33
var text_reveal : bool = false
var current_visible_characters : int = 0


# --- Configuration ---
## Controls the tail's position along the specified edge.
## 0.0 = left/top, 0.5 = center, 1.0 = right/bottom.
## Appears as a slider in the Inspector for easy artistic control.
@export_range(0.0, 1.0, 0.01) var tail_edge_position: float = 0.8


func _ready():
	# Bubbles should start hidden and be shown by the DialoguePlayer.
	hide()
	# Await one frame to ensure initial sizing is correct before placing the tail.
	await get_tree().process_frame

func _process(delta):
	if text_reveal:
		var char_count = bubble_text.get_total_character_count()
		if char_count > 0:
			if bubble_text.visible_ratio < 1:
				bubble_text.visible_ratio += (1.0 / char_count) * (TEXT_SPEED_CPS * delta)
			else:
				text_reveal = false
		else:
			text_reveal = false

func show_text(text: String):
	bubble_text.text = text
	bubble_text.visible_ratio = 0
	text_reveal = true
	show()
	animator.pop_in()

func hide_and_finish():
	await animator.pop_out()
	hide()
	finished.emit()

func advance():
	if text_reveal:
		text_reveal = false
		bubble_text.visible_ratio = 1.0
	else:
		hide_and_finish()

func skip_text():
	bubble_text.visible_ratio = 1
