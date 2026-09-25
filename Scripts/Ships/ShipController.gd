class_name ShipController
extends RigidBody3D
## Controlador de nave espacial basado en físicas RigidBody3D (RF-05)

@export var _stats: Resource
@export var _mesh_path: NodePath # para inclinación visual

var _throttle: float = 0.0
var _steer_input: float = 0.0
var _braking: bool = false
var _boosting: bool = false
var _control_enabled: bool = true

var throttle: float = 0.0
var current_speed: float = 0.0

# Ratio de velocidad seguro evitando división por cero
var speed_ratio: float:
	get:
		var max_spd: float = _stats.max_speed if (_stats != null and "max_speed" in _stats) else (_stats.MaxSpeed if (_stats != null and "MaxSpeed" in _stats) else 35.0)
		return clampf(current_speed / max_spd, 0.0, 1.5) if max_spd > 0.0 else 0.0

var control_enabled: bool:
	get: return _control_enabled
	set(value):
		_control_enabled = value
		if not _control_enabled:
			_throttle = 0.0
			_steer_input = 0.0
			_braking = false
			_boosting = false

func _ready() -> void:
	if _stats == null:
		_stats = ShipStats.new()

	# Se asigna la masa desde _stats con un valor por defecto de respaldo
	var mass_val: float = _stats.mass if "mass" in _stats else (_stats.Mass if "Mass" in _stats else 1000.0)
	mass = mass_val if mass_val > 0.0 else 1000.0

	linear_damp = _stats.linear_damping if "linear_damping" in _stats else (_stats.LinearDamping if "LinearDamping" in _stats else 0.15)
	angular_damp = _stats.angular_damping if "angular_damping" in _stats else (_stats.AngularDamping if "AngularDamping" in _stats else 1.5)
	can_sleep = false

func _physics_process(delta: float) -> void:
	var d := float(delta)
	current_speed = linear_velocity.length()

	_update_throttle_from_input()
	_apply_hover_forces(d)
	_apply_steering(d)
	_apply_engine_force(d)
	_clamp_speed()
	_apply_banking(d)
	_update_visuals()

func _update_throttle_from_input() -> void:
	# Ajustar estas acciones según el InputMap de Godot
	_throttle = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
	throttle = _throttle
	_braking = Input.is_action_pressed("brake")
	_boosting = Input.is_action_pressed("boost")
	_steer_input = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")

func _apply_hover_forces(_delta: float) -> void:
	# Lógica de suspensión o gravedad personalizada según diseño
	pass

func _apply_steering(_delta: float) -> void:
	# Lógica de giro
	pass

func _apply_engine_force(_delta: float) -> void:
	if _stats != null:
		var accel: float = _stats.acceleration if "acceleration" in _stats else (_stats.Acceleration if "Acceleration" in _stats else 24.0)
		var target_force: float = _throttle * accel
		apply_central_force(transform.basis.z * -target_force)

func _clamp_speed() -> void:
	if _stats == null:
		return

	var max_spd: float = _stats.max_speed if "max_speed" in _stats else (_stats.MaxSpeed if "MaxSpeed" in _stats else 35.0)
	var boost_mult: float = _stats.boost_multiplier if "boost_multiplier" in _stats else (_stats.BoostMultiplier if "BoostMultiplier" in _stats else 1.5)
	var max_limit: float = max_spd * boost_mult if _boosting else max_spd
	if linear_velocity.length() > max_limit:
		linear_velocity = linear_velocity.normalized() * max_limit

func _apply_banking(_delta: float) -> void:
	# Inclinación visual de la nave al girar
	pass

func _update_visuals() -> void:
	# Actualización de partículas o mallas
	pass
