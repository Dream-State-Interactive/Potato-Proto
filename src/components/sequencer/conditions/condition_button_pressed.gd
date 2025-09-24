# src/components/sequencer/conditions/condition_button_pressed.gd
extends Condition
class_name ConditionButtonPressed

@export var button_path: NodePath

var _was_pressed := false
var _button: PhysicsButton = null
var _bound := false

func bind(actor: Node) -> void:
	if _bound and is_instance_valid(_button):
		return
	_bound = true
	_was_pressed = false
	_button = null

	if button_path.is_empty():
		push_warning("ConditionButtonPressed: 'button_path' is empty.")
		return

	var btn: PhysicsButton = null
	if button_path.is_absolute():
		btn = actor.get_tree().root.get_node_or_null(button_path) as PhysicsButton
	else:
		var base: Node = actor
		while base and not base.has_node(button_path):
			base = base.get_parent()
		if base:
			btn = base.get_node(button_path) as PhysicsButton

	_button = btn
	if _button:
		if not _button.is_connected("pressed", Callable(self, "_on_button_pressed")):
			_button.pressed.connect(_on_button_pressed, Object.CONNECT_ONE_SHOT)
	else:
		push_warning("ConditionButtonPressed: Could not resolve button at '%s'." % str(button_path))

func check(actor: Node2D) -> bool:
	# Auto-rebind if needed (e.g., scene reloaded, or condition duplicated)
	if not _bound or not is_instance_valid(_button):
		bind(actor)
	return _was_pressed

func _on_button_pressed() -> void:
	_was_pressed = true
