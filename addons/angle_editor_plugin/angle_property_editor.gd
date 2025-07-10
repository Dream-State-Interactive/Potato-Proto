# Filename: res://addons/angle_editor_plugin/angle_property_editor.gd

## An EditorProperty that provides a custom UI for editing an angle value.
## It features an interactive visual dial and allows for precise text input
## by clicking on the number. This entire control is drawn manually
## to ensure a clean appearance without visual artifacts.
@tool
class_name AnglePropertyEditor
extends EditorProperty

# --- State management variables ---
var _dragging := false               # Is the user currently dragging the dial?
var _is_text_editing := false        # Is the user currently typing in a value?
var _text_edit_string := ""          # The current text being typed by the user.
var _overwrite_on_next_input := false # A flag to make the first keypress replace the text.

# --- Layout variables, calculated dynamically ---
var _dial_center: Vector2
var _dial_radius: float
var _text_rect: Rect2 # A fixed-size rectangle that defines where the text is drawn.

# Called once when the control is created.
func _init():
	# Set a comfortable height for our control in the Inspector.
	custom_minimum_size.y = 60
	# Allow this control to receive focus so it can accept keyboard input for text editing.
	focus_mode = FOCUS_ALL

# Godot's main input handling function for UI controls.
func _gui_input(event: InputEvent) -> void:
	# The layout must be recalculated on every input event to ensure click detection
	# is accurate, as the control's size can change.
	_recalculate_layout()

	# --- 1. Handle Keyboard Input when in text editing mode ---
	if _is_text_editing:
		if event is InputEventKey and event.is_pressed():
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_commit_text_edit() # User pressed Enter, confirm the new value.
			elif event.keycode == KEY_ESCAPE:
				_cancel_text_edit() # User pressed Escape, cancel the edit.
			elif event.keycode == KEY_BACKSPACE and not _text_edit_string.is_empty():
				_text_edit_string = _text_edit_string.left(_text_edit_string.length() - 1)
				_overwrite_on_next_input = false # No longer overwriting, just editing.
			elif event.unicode != 0:
				var char := char(event.unicode)
				
				# Validate the character to ensure we're building a valid number.
				var is_digit := char in "0123456789"
				var is_period := (char == "." and not "." in _text_edit_string) # Only one decimal point allowed.
				var is_minus := (char == "-" and _text_edit_string.is_empty())  # Only one minus sign at the start.
				
				if is_digit or is_period or is_minus:
					if _overwrite_on_next_input:
						_text_edit_string = char # The first keypress replaces the old value.
						_overwrite_on_next_input = false
					else:
						_text_edit_string += char # Subsequent keypresses append.
			
			queue_redraw() # Redraw to show the updated text string.
			accept_event() # Consume the key press event.
		elif event is InputEventMouseButton and event.is_pressed():
			# If the user clicks anywhere else while editing, commit the text.
			if not _text_rect.has_point(event.position):
				_commit_text_edit()
		return # Stop any other input handling while in text edit mode.

	# --- 2. Handle Mouse Input for the dial and for starting text edit ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Check for a click or double-click inside the text area.
		if (event.is_double_click() or event.is_pressed()) and _text_rect.has_point(event.position):
			if not _is_text_editing:
				_start_text_edit() # Start text editing mode.
			accept_event()
		elif event.is_pressed():
			# Check for a click on the dial to start dragging.
			if event.position.distance_to(_dial_center) < _dial_radius * 1.5:
				_dragging = true
				_update_angle_from_position(event.position)
				accept_event()
		elif _dragging: # On mouse button release
			_dragging = false
			accept_event()
			
	if event is InputEventMouseMotion and _dragging:
		_update_angle_from_position(event.position)
		accept_event()

## Calculates the angle from the dial's center to the mouse and updates the property.
func _update_angle_from_position(pos: Vector2) -> void:
	if _is_text_editing: _cancel_text_edit() # Cancel text edit if user drags dial.
	var angle_rad := (pos - _dial_center).angle()
	var angle_deg := rad_to_deg(angle_rad)
	if angle_deg < 0: angle_deg += 360 # Normalize to 0-360.
	
	# This is the key function that tells the editor the property has a new value.
	# It also automatically handles Undo/Redo actions.
	emit_changed(get_edited_property(), angle_deg)

## Switches the control into text-editing mode.
func _start_text_edit() -> void:
	_is_text_editing = true
	_overwrite_on_next_input = true # Flag that the next keypress should clear the text.
	# Start with the current value, formatted to one decimal place.
	_text_edit_string = "%.1f" % float(get_edited_object().get(get_edited_property()))
	queue_redraw()

## Confirms the typed value, validates it, and exits text-editing mode.
func _commit_text_edit() -> void:
	if _text_edit_string.is_valid_float():
		var new_value := float(_text_edit_string)
		# Safeguard: Clamp the value to be within the 0-360 degree range.
		new_value = clampf(new_value, 0.0, 360.0)
		emit_changed(get_edited_property(), new_value)
	_cancel_text_edit()

## Exits text-editing mode without applying changes.
func _cancel_text_edit() -> void:
	_is_text_editing = false
	_overwrite_on_next_input = false
	_text_edit_string = ""
	queue_redraw()

## Calculates the positions and sizes of UI elements based on the control's current size.
func _recalculate_layout():
	var control_size := get_size()
	_dial_radius = control_size.y * 0.4
	# Position the dial on the right side, with a 30px buffer for the revert button.
	_dial_center = Vector2(control_size.x - _dial_radius - 30, control_size.y / 2.0)
	
	# Define a stable, fixed-size rectangle for our text area. This prevents visual jitter.
	var text_area_width = 60
	var text_area_height = 30
	var text_area_pos = Vector2(_dial_center.x - _dial_radius - 10 - text_area_width, _dial_center.y - text_area_height / 2.0)
	_text_rect = Rect2(text_area_pos, Vector2(text_area_width, text_area_height))

## Godot's main drawing function. This draws the entire control manually.
func _draw() -> void:
	_recalculate_layout()
	var font := get_theme_font("font", "EditorFonts")
	var font_color := get_theme_color("font_color", "Editor")
	var current_angle := float(get_edited_object().get(get_edited_property()))
	
	var text_to_draw: String
	
	if _is_text_editing:
		# If editing, draw a background box that mimics a LineEdit.
		var stylebox := get_theme_stylebox("normal", "LineEdit")
		stylebox.draw(get_canvas_item(), _text_rect)
		text_to_draw = _text_edit_string
	else:
		# If just displaying, format the angle to one decimal place.
		text_to_draw = "%.1f" % current_angle + "°"

	# Unify the drawing logic for both states to ensure perfect alignment.
	var text_draw_pos = Vector2(_text_rect.position.x, _text_rect.position.y + (_text_rect.size.y - font.get_string_size(text_to_draw, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).y) / 2.0 + font.get_ascent(16))
	draw_string(font, text_draw_pos, text_to_draw, HORIZONTAL_ALIGNMENT_RIGHT, _text_rect.size.x, 16, font_color)

	# Always draw the dial on top.
	draw_circle(_dial_center, _dial_radius, Color.BLACK)
	var direction := Vector2.from_angle(deg_to_rad(current_angle))
	draw_line(_dial_center, _dial_center + direction * _dial_radius, Color.WHITE, 2.0)

## This function is called by the editor when the property is changed externally.
func _update_property() -> void:
	# Simply request a redraw to reflect the new value.
	queue_redraw()
