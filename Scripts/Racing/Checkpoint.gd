class_name Checkpoint
extends Area3D
## Checkpoint para cálculo de progreso de carrera y línea de meta (RF-06)

@export var index: int = 0
@export var is_finish_line: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true

func _on_body_entered(body: Node3D) -> void:
	var participant := body.get_node_or_null("RaceParticipant")
	if participant == null:
		participant = body.find_child("RaceParticipant", true, false)

	if participant != null:
		if is_finish_line:
			if participant.has_method("register_finish_line_entry"):
				participant.register_finish_line_entry()
			elif participant.has_method("RegisterFinishLineEntry"):
				participant.RegisterFinishLineEntry()
		else:
			if participant.has_method("register_checkpoint_entry"):
				participant.register_checkpoint_entry(self)
			elif participant.has_method("RegisterCheckpointEntry"):
				participant.RegisterCheckpointEntry(self)
