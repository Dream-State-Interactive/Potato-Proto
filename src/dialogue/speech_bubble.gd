# src/dialogue/speech_bubble.gd
@tool
class_name SpeechBubble
extends Control

@onready var bubble_bg: NinePatchRect = $BubbleBG
@onready var bubble_text: RichTextLabel = $BubbleBG/BubbleText
@onready var animator: CGuiScale = $CGUIScale

signal finished

const TEXT_SPEED_CPS: float = 33.0
var text_reveal: bool = false

@export_range(0.0, 1.0, 0.01) var tail_edge_position: float = 0.8

@export_group("Auto Size")
@export var min_width: float = 18.0
@export var max_width: float = 560.0
@export var padding: Vector2 = Vector2(48.0, 32.0) # x = left/right, y = top/bottom
@export var min_height: float = 0.0
@export var max_height: float = 0.0 # 0 = no clamp

@export_group("Resize Animation")
@export var animate_resize: bool = true
@export var resize_time: float = 0.12

var _resize_tween: Tween
var _pending_layout: bool = false

func _ready() -> void:
	# Avoid messing with layout while editing the scene in the editor.
	if Engine.is_editor_hint():
		set_process(false)
		return

	set_process(true)
	hide()

	# Make sure visibility isn't killed by modulate from previous tweens.
	modulate.a = 1.0
	bubble_text.modulate.a = 1.0

	# Robust defaults for RichTextLabel
	bubble_text.scroll_active = false
	bubble_text.fit_content = false
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Debug safety: don't clip unless you explicitly want it
	bubble_bg.clip_contents = false

func _process(delta: float) -> void:
	if not text_reveal:
		return

	var total: int = bubble_text.get_total_character_count()
	if total <= 0:
		text_reveal = false
		return

	var add_chars: int = int(floor(TEXT_SPEED_CPS * delta))
	if add_chars < 1:
		add_chars = 1

	var current: int = bubble_text.visible_characters
	if current < 0:
		current = 0

	bubble_text.visible_characters = min(current + add_chars, total)

	if bubble_text.visible_characters >= total:
		text_reveal = false

func show_text(text: String) -> void:
	# Show first so Godot actually lays out controls.
	show()

	# Set text and make it fully visible for the sizing pass.
	bubble_text.text = text
	bubble_text.visible_characters = -1
	bubble_text.scroll_active = false

	_request_layout()

	# Play pop animation (safe even before layout finishes)
	if animator:
		animator.pop_in()

func hide_and_finish() -> void:
	if animator:
		await animator.pop_out()
	hide()
	finished.emit()

func advance() -> void:
	if text_reveal:
		text_reveal = false
		bubble_text.visible_characters = -1
	else:
		hide_and_finish()

func skip_text() -> void:
	text_reveal = false
	bubble_text.visible_characters = -1

# -----------
# Auto sizing
# -----------

func _request_layout() -> void:
	if _pending_layout:
		return
	_pending_layout = true
	call_deferred("_layout_to_text")

func _layout_to_text() -> void:
	_pending_layout = false

	var outer_w: float = _compute_outer_width()

	# Set root + bg width immediately (height is temporary)
	size = Vector2(outer_w, 40.0)
	bubble_bg.position = Vector2.ZERO
	bubble_bg.size = size

	# Inner rect for text (width determines wrapping)
	bubble_text.position = Vector2(padding.x, padding.y)
	bubble_text.size = Vector2(maxf(1.0, outer_w - padding.x * 2.0), 10.0)

	# Let RichTextLabel compute its own height from wrapped text.
	bubble_text.fit_content = true
	bubble_text.scroll_active = false

	await get_tree().process_frame

	# When fit_content = true, label height becomes content height
	var content_h: float = bubble_text.size.y
	if content_h <= 0.0:
		content_h = float(bubble_text.get_content_height())
		if content_h <= 0.0:
			content_h = 24.0

	var desired_outer_h: float = content_h + padding.y * 2.0
	if min_height > 0.0:
		desired_outer_h = maxf(desired_outer_h, min_height)

	var should_scroll: bool = false
	if max_height > 0.0 and desired_outer_h > max_height:
		should_scroll = true
		desired_outer_h = max_height

	_apply_bubble_size(Vector2(outer_w, desired_outer_h), should_scroll)

	bubble_text.fit_content = false
	bubble_text.visible_characters = 0
	text_reveal = true

func _apply_bubble_size(target_size: Vector2, should_scroll: bool) -> void:
	var inner_h: float = maxf(1.0, target_size.y - padding.y * 2.0)

	# Apply scroll if clamped
	bubble_text.scroll_active = should_scroll
	bubble_text.size.y = inner_h
	if should_scroll:
		bubble_text.scroll_vertical = 0

	# Resize root & bg
	if not animate_resize or resize_time <= 0.0:
		size = target_size
		bubble_bg.size = target_size
	else:
		if _resize_tween:
			_resize_tween.kill()
		_resize_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
		_resize_tween.tween_property(self, "size", target_size, resize_time)
		_resize_tween.tween_property(bubble_bg, "size", target_size, resize_time)

	# Keep pivot centered for pop scaling
	if animator and animator.has_method("recenter_pivot"):
		animator.recenter_pivot()

func _compute_outer_width() -> float:
	# Use plain text for width measurement (bbcode/formatting ignored).
	var s: String = bubble_text.get_parsed_text()
	if s.is_empty():
		s = bubble_text.text

	var font: Font = bubble_text.get_theme_font("normal_font")
	if font == null:
		return max_width

	var font_size: int = bubble_text.get_theme_font_size("normal_font_size")
	var lines: PackedStringArray = s.split("\n", false)

	var widest: float = 0.0
	for line in lines:
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		widest = maxf(widest, w)

	var desired: float = widest + padding.x * 2.0
	desired = clampf(desired, min_width, max_width)
	return desired
