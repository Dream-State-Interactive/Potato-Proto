# src/components/sequencer/c_condition.gd
extends Resource
class_name Condition

## Override this method in a custom condition script.
## 'actor' is the Node2D running the sequence.
func check(_actor: Node2D) -> bool:
	return false
