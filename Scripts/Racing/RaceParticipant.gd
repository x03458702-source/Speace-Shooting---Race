class_name RaceParticipant
extends Node
## Participante de carrera para seguimiento de vueltas, checkpoints y tiempo (RF-06)

signal lap_completed(lap: int, total_laps: int)
signal race_finished()

@export var display_name: String = "Nave"

var laps_completed: int = 0
var next_checkpoint_index: int = 0
var progress_score: float = 0.0 # para el ranking
var finished: bool = false
var finish_time: float = 0.0

var _race_manager: Node

func initialize(rm: Node, position_along_track: float) -> void:
	_race_manager = rm
	progress_score = position_along_track
	laps_completed = 0
	next_checkpoint_index = 0
	finished = false
	finish_time = 0.0

func register_checkpoint_entry(cp: Node) -> void:
	if finished or _race_manager == null:
		return

	var cp_index: int = cp.index if "index" in cp else (cp.Index if "Index" in cp else 0)
	var cp_count: int = _race_manager.checkpoint_count if "checkpoint_count" in _race_manager else (_race_manager.CheckpointCount if "CheckpointCount" in _race_manager else 1)

	if cp_index == next_checkpoint_index:
		next_checkpoint_index = (next_checkpoint_index + 1) % cp_count
		progress_score = laps_completed * 1000.0 + next_checkpoint_index * 100.0

func register_finish_line_entry() -> void:
	if finished or _race_manager == null:
		return

	var total_laps_count: int = _race_manager.total_laps if "total_laps" in _race_manager else (_race_manager.TotalLaps if "TotalLaps" in _race_manager else 3)
	var elapsed: float = _race_manager.race_elapsed_time if "race_elapsed_time" in _race_manager else (_race_manager.RaceElapsedTime if "RaceElapsedTime" in _race_manager else 0.0)

	laps_completed += 1
	emit_signal("lap_completed", laps_completed, total_laps_count)

	if laps_completed >= total_laps_count:
		finished = true
		finish_time = elapsed
		emit_signal("race_finished")
