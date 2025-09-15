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

func start_sequence(sequence_name: StringName) -> void:
	if not runners.has(sequence_name):
		push_error("MANAGER: FAILED to start. Runner '%s' not found." % sequence_name)
		return

	print("MANAGER: Attempting to start runner '%s'." % sequence_name)
	var runner_to_start: SequenceRunnerComponent = runners[sequence_name]
	active_runner = runner_to_start
	active_runner.start(true)
	print("MANAGER: Start command issued to runner '%s'." % sequence_name)

func switch_sequence(new_sequence_name: StringName) -> void:
	print("MANAGER: ----- SEQUENCE SWITCH INITIATED -----")
	print("MANAGER: Switching to '%s'." % new_sequence_name)
	
	if is_instance_valid(active_runner):
		print("MANAGER: Stopping current runner '%s'." % active_runner.name)
		active_runner.stop()
		print("MANAGER: Stop command issued to runner '%s'." % active_runner.name)
	else:
		print("MANAGER: No active runner to stop.")

	start_sequence(new_sequence_name)
	print("MANAGER: ----- SEQUENCE SWITCH COMPLETE -----")
