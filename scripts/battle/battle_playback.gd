class_name BattlePlayback
extends RefCounted
## Drives a BattleSimulator in real time for the battle screen: speed, pause, skip and retreat.
## Pure logic (no nodes), so it can be tested headless.

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var simulator: BattleSimulator
var speed := 1.0
var paused := false
## Seconds of battle time not yet simulated (less than one tick).
var _pending := 0.0
## Index of the first event in simulator.record.events not yet returned by advance().
var _event_cursor := 0


func _init(p_simulator: BattleSimulator) -> void:
	simulator = p_simulator


func is_finished() -> bool:
	return simulator.finished


## Runs the simulation for `real_delta` seconds of real time (times `speed`) and returns the
## events that happened, so the screen can play their effects. Returns nothing while paused.
func advance(real_delta: float) -> Array[Dictionary]:
	if not paused and not simulator.finished:
		_pending += real_delta * speed
		while _pending >= BattleSimulator.TICK - 0.000001 and not simulator.finished:
			simulator.step()
			_pending -= BattleSimulator.TICK
	return _take_new_events()


## Simulates the rest of the battle at once. Events from the skipped part are dropped.
func skip() -> void:
	while not simulator.finished:
		simulator.step()
	_event_cursor = simulator.record.events.size()


func retreat(side: int) -> void:
	simulator.retreat(side)


func _take_new_events() -> Array[Dictionary]:
	var events := simulator.record.events
	var result: Array[Dictionary] = []
	result.assign(events.slice(_event_cursor))
	_event_cursor = events.size()
	return result
