class_name RaceManager
extends Node
## Gestor de Carrera y Participantes (Racing System - Sección 10.3)

enum RaceState {
	IDLE,
	COUNTDOWN,
	RACING,
	FINISHED
}

static var instance: RaceManager

signal race_started(manager: RaceManager, timestamp: float)
signal lap_completed(participant: Node, lap: int, total_laps: int)
signal race_finished(participant: Node, time: float, position: int)
signal racer_eliminated(participant: Node)

var checkpoints: Array[Node] = []
var participants: Array[Node] = []
var checkpoint_count: int:
	get: return checkpoints.size()
var state: RaceState = RaceState.IDLE
var race_elapsed_time: float = 0.0
var countdown_ends_at: float = 0.0

@export var total_laps: int = 3

func _ready() -> void:
	instance = self

func register_checkpoint(cp: Node) -> void:
	if not checkpoints.has(cp):
		checkpoints.append(cp)
		_enforce_index_order()

func _enforce_index_order() -> void:
	checkpoints.sort_custom(func(a, b):
		var idx_a: int = a.index if "index" in a else (a.Index if "Index" in a else 0)
		var idx_b: int = b.index if "index" in b else (b.Index if "Index" in b else 0)
		return idx_a < idx_b
	)

func start_race(racers: Array, laps: int, countdown_seconds: float) -> void:
	if checkpoints.is_empty():
		push_error("¡No se pueden iniciar la carrera! No hay checkpoints registrados.")
		return

	participants.clear()
	for r in racers:
		participants.append(r)
	total_laps = laps

	for p in participants:
		if p != null and p.get_parent() is Node3D:
			var ship_node: Node3D = p.get_parent()
			if ship_node.has_method("set_control_enabled"):
				ship_node.set_control_enabled(false)
			elif ship_node.has_method("SetControlEnabled"):
				ship_node.call("SetControlEnabled", false)

	state = RaceState.COUNTDOWN
	countdown_ends_at = (Time.get_ticks_msec() / 1000.0) + countdown_seconds

	emit_signal("race_started", self, Time.get_ticks_msec() / 1000.0)

func _physics_process(delta: float) -> void:
	if state == RaceState.COUNTDOWN:
		var current_time := Time.get_ticks_msec() / 1000.0
		if current_time >= countdown_ends_at:
			_to_racing()
		return

	if state == RaceState.RACING:
		race_elapsed_time += delta
		_update_rankings()

func _to_racing() -> void:
	state = RaceState.RACING
	race_elapsed_time = 0.0

	for p in participants:
		if p != null and p.get_parent() is Node3D:
			var owner_node: Node3D = p.get_parent()
			var controller := owner_node.get_node_or_null("ShipController")
			if controller == null:
				controller = owner_node.find_child("ShipController", true, false)
			if controller != null:
				if "control_enabled" in controller:
					controller.control_enabled = true
				elif "ControlEnabled" in controller:
					controller.ControlEnabled = true

func _update_rankings() -> void:
	if participants.is_empty():
		return
	participants.sort_custom(func(a, b):
		var score_a: float = a.progress_score if "progress_score" in a else (a.ProgressScore if "ProgressScore" in a else 0.0)
		var score_b: float = b.progress_score if "progress_score" in b else (b.ProgressScore if "ProgressScore" in b else 0.0)
		return score_a > score_b
	)
