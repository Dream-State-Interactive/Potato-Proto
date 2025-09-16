# src/components/sequencer/c_sequence_manager.gd
extends Node
class_name SequenceManager

@export var initial_sequence: StringName

var runners: Dictionary = {}
var active_runner: SequenceRunnerComponent = null

func _ready() -> void:
	await get_parent().ready
	for child in get_parent().get_children():
		if child is SequenceRunnerComponent:
			var runner := child as SequenceRunnerComponent
			runners[runner.name] = runner
	
	if not initial_sequence.is_empty():
		start_sequence(initial_sequence)
	else:
		for runner_name in runners:
			var runner: SequenceRunnerComponent = runners[runner_name]
			if runner.is_default_runner:
				start_sequence(runner.name)
				return
		push_warning("SequenceManager: No initial sequence set and no default runner found.")

func has_runner(name: StringName) -> bool:
	return runners.has(name)

func start_sequence(sequence_name: StringName) -> void:
	if not runners.has(sequence_name):
		push_error("MANAGER: runner '%s' not found." % sequence_name)
		return
	var r: SequenceRunnerComponent = runners[sequence_name]
	active_runner = r
	active_runner.start(true)

func switch_sequence(new_sequence_name: StringName) -> void:
	if is_instance_valid(active_runner):
		active_runner.stop()
	start_sequence(new_sequence_name)
