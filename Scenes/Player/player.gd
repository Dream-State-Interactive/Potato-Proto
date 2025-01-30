extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_pressed("click"):
		$RigidBody2D.add_constant_torque(60000 * delta)
	elif Input.is_action_pressed("right_click"):
		$RigidBody2D.set_angular_velocity(0)
	else:
		$RigidBody2D.set_constant_torque(0)
		
	if Input.is_action_just_released("scroll_up"):
		var zoom := Vector2($RigidBody2D/Camera2D.get_zoom())
		zoom *= 1.2
		$RigidBody2D/Camera2D.set_zoom(zoom)
		print(zoom)
	elif Input.is_action_just_released("scroll_down"):
		var zoom := Vector2($RigidBody2D/Camera2D.get_zoom())
		zoom *= 1/1.2
		$RigidBody2D/Camera2D.set_zoom(zoom)
		print(zoom)
		
	# elif Input.is_action_pressed("scroll_down"):
