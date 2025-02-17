extends Resource
class_name CustomAction

@export var target: NodePath = ""  # NodePath to target (optional)
@export var method: String = ""  # Method name to call
@export var params: Array = []  # Parameters to pass
@export var delay: float = 0.0  # Delay before execution
