class_name OndaBomba
extends Area3D
## Onda Expansiva de Bomba de Área (RF-12)
## Genera una onda expansiva esférica de energía que limpia obstáculos y desplaza rivales.

@export var radio_maximo: float = 34.0
@export var duracion_expansion: float = 0.55

var creador: Node = null
var es_jugador: bool = false
var _radio_actual: float = 1.0
var _forma_colision: SphereShape3D
var _malla_onda: MeshInstance3D
var _mat_onda: StandardMaterial3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4 | 16 # Rivales (2), Obstáculos (4), Trampas (16)
	if not es_jugador:
		collision_mask |= 1 # Si la lanzó una IA, también puede afectar al jugador
	
	_construir_visuales()
	_crear_colision()
	
	body_entered.connect(_al_detectar_cuerpo)
	area_entered.connect(_al_detectar_area)
	
	_ejecutar_expansion()

func _construir_visuales() -> void:
	_malla_onda = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	_malla_onda.mesh = esfera
	
	_mat_onda = StandardMaterial3D.new()
	_mat_onda.albedo_color = Color(1.0, 0.75, 0.15, 0.7)
	_mat_onda.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_onda.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_onda.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_onda.emission_enabled = true
	_mat_onda.emission = Color(1.0, 0.8, 0.2)
	_mat_onda.emission_energy_multiplier = 4.0
	_malla_onda.material_override = _mat_onda
	add_child(_malla_onda)

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	_forma_colision = SphereShape3D.new()
	_forma_colision.radius = 1.0
	col.shape = _forma_colision
	add_child(col)

func _ejecutar_expansion() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_method(_actualizar_radio, 1.0, radio_maximo, duracion_expansion).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_mat_onda, "albedo_color:a", 0.0, duracion_expansion).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(queue_free)

func _actualizar_radio(r: float) -> void:
	_radio_actual = r
	_forma_colision.radius = r
	_malla_onda.scale = Vector3.ONE * r

func _al_detectar_cuerpo(cuerpo: Node3D) -> void:
	_afectar_objeto(cuerpo)

func _al_detectar_area(area: Area3D) -> void:
	_afectar_objeto(area)
	if area.get_parent() != null:
		_afectar_objeto(area.get_parent())

func _afectar_objeto(obj: Node) -> void:
	if obj == null or obj == creador:
		return

	# Si es un obstáculo destruible (asteroide)
	if obj.has_method("destruir_por_bomba"):
		obj.destruir_por_bomba(es_jugador)
		return

	# Si es una trampa de aceite, la evapora
	if obj is TrampaAceite:
		obj.queue_free()
		return

	# Si es una nave (rival o jugador)
	if obj.has_method("recibir_impacto_bomba"):
		var obj_3d := obj as Node3D
		if obj_3d == null:
			return
		var direccion_empuje: Vector3 = (obj_3d.global_position - global_position).normalized()
		obj.recibir_impacto_bomba(direccion_empuje)
		if es_jugador and obj.is_in_group("rivales"):
			var rm := get_tree().root.find_child("RaceManager", true, false)
			if rm != null and rm.has_method("sumar_puntos_jugador"):
				rm.sumar_puntos_jugador(150)
