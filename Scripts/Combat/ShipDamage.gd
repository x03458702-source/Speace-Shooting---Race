class_name ShipDamage
extends Area3D
## Área en la nave que detecta cuerpos peligrosos e impactos (ECS - Sección 10.2)

signal hit_taken(current_lives: int)
signal ship_destroyed()

@export var max_lives: int = 3
@export var invulnerability_time: float = 1.5
@export var hit_impulse: float = 10.0

var lives: int = 3
var _is_invulnerable: bool = false

func _ready() -> void:
	lives = max_lives
	body_entered.connect(_on_body_entered)
	monitoring = true

func _on_body_entered(body: Node3D) -> void:
	if _is_invulnerable or lives <= 0:
		return

	take_damage(1)

	# Aplicar rebote si el nodo padre de esta área es un RigidBody3D
	var parent := get_parent()
	if parent is RigidBody3D:
		var bounce_dir: Vector3 = (parent.global_position - body.global_position).normalized()
		parent.apply_central_impulse(bounce_dir * hit_impulse)

func take_damage(amount: int) -> void:
	if _is_invulnerable or lives <= 0:
		return

	lives = clampi(lives - amount, 0, max_lives)
	emit_signal("hit_taken", lives)

	if lives <= 0:
		emit_signal("ship_destroyed")
	else:
		start_invulnerability()

func start_invulnerability() -> void:
	_is_invulnerable = true
	await get_tree().create_timer(invulnerability_time).timeout
	_is_invulnerable = false
