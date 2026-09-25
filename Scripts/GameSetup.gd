class_name GameSetup
extends Node3D
## Configuración e inicio de carrera (Racing System)

@export var total_laps: int = 2
@export var countdown_seconds: float = 3.0

func _ready() -> void:
	var manager := get_node_or_null("/root/RaceManager")
	if manager == null:
		return

	var player_participant := get_node_or_null("Player/RaceParticipant")
	var players: Array = []
	if player_participant != null:
		players.append(player_participant)

	# Suscripción a las señales del RaceManager
	if manager.has_signal("lap_completed"):
		manager.lap_completed.connect(_on_lap_completed)
	if manager.has_signal("race_started"):
		manager.race_started.connect(_on_race_started)
	if manager.has_signal("race_finished"):
		manager.race_finished.connect(_on_race_finished)

	# Iniciar la carrera pasando la lista de jugadores, vueltas y el tiempo de cuenta atrás
	if manager.has_method("start_race"):
		manager.start_race(players, total_laps, countdown_seconds)

func _on_lap_completed(_participant: Node, lap: int, total_laps_count: int) -> void:
	print("¡Vuelta %d de %d completada!" % [lap, total_laps_count])

func _on_race_started(_manager: Node, _timestamp: float) -> void:
	print("¡Cuenta atrás finalizada, la carrera ha comenzado!")

func _on_race_finished(_participant: Node, time: float, position: int) -> void:
	print("Participante ha terminado la carrera en la posición %d con un tiempo de %.2f segundos." % [position, time])
