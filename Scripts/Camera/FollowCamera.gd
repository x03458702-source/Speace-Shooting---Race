class_name FollowCamera
extends Camera3D
## Cámara perseguidora en 3ª persona (Sección 25)
## Sigue suavemente la nave, orienta la vista hacia adelante y ajusta el FOV con la velocidad.

@export var target_path: NodePath
@export var distance: float = 8.0
@export var height: float = 3.5
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 6.0
@export var fov_min: float = 70.0
@export var fov_max: float = 78.0

var _target: Node3D
var _ship_controller: Node

func _ready() -> void:
	if not target_path.is_empty():
		_target = get_node_or_null(target_path)
		if _target != null:
			if _target.has_method("get_speed_ratio") or "speed_ratio" in _target or "SpeedRatio" in _target:
				_ship_controller = _target
			else:
				_ship_controller = _target.get_node_or_null("ShipController")
				if _ship_controller == null:
					_ship_controller = _target.find_child("ShipController", true, false)

func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var dt := float(delta)

	# En Godot, el frente de un objeto 3D suele ser el eje -Z
	var target_forward: Vector3 = -_target.global_transform.basis.z

	# Posición deseada detrás de la nave y elevada
	var desired_pos: Vector3 = _target.global_position - (target_forward * distance) + (Vector3.UP * height)

	# Movimiento suave de la cámara usando amortiguación exponencial independiente del framerate
	global_position = global_position.lerp(desired_pos, 1.0 - exp(-follow_speed * dt))

	# Punto hacia donde debe mirar la cámara (ligeramente elevado respecto al centro de la nave)
	var look_target: Vector3 = _target.global_position + (Vector3.UP * 1.0)

	# Creamos la transformación orientada al objetivo y la interpolamos suavemente
	var target_transform := global_transform.looking_at(look_target, Vector3.UP)
	global_transform = global_transform.interpolate_with(target_transform, 1.0 - exp(-rotation_speed * dt))

	# Ajuste dinámico del FOV basado en la velocidad de la nave (speed_ratio)
	if _ship_controller != null:
		var speed_ratio: float = 0.0
		if "speed_ratio" in _ship_controller:
			speed_ratio = _ship_controller.speed_ratio
		elif "SpeedRatio" in _ship_controller:
			speed_ratio = _ship_controller.SpeedRatio
		var target_fov: float = lerpf(fov_min, fov_max, speed_ratio)
		fov = lerpf(fov, target_fov, 5.0 * dt)
