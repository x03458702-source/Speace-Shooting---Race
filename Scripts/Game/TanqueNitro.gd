class_name TanqueNitro
extends Area3D
## Tanque de Nitro (Azul: recarga 30%, Morado: recarga 60%)
## Flota sobre la pista, rota y otorga nitro al jugador al colisionar.

@export var tiempo_reaparicion: float = 14.0
@export var recarga_porcentaje: float = 30.0 # 30.0 para azul, 60.0 para morado
@export var es_morado: bool = false

var _malla: MeshInstance3D
var _nucleo: MeshInstance3D
var _luz: OmniLight3D
var _disponible: bool = true
var _tiempo_espera: float = 0.0
var _altura_base: float = 2.2
var _angulo: float = 0.0

func _ready() -> void:
	collision_layer = 8       # Capa de elementos interactivos / cajas
	collision_mask = 1        # Capa del jugador
	_construir_visuales()
	_crear_colision()
	body_entered.connect(_al_entrar_cuerpo)
	area_entered.connect(_al_entrar_area)

func configurar_tipo(morado: bool) -> void:
	es_morado = morado
	recarga_porcentaje = 60.0 if es_morado else 30.0
	if _malla and _luz:
		_actualizar_materiales()

func _construir_visuales() -> void:
	# Cilindro o tanque exterior
	_malla = MeshInstance3D.new()
	var cilindro_mesh := CylinderMesh.new()
	cilindro_mesh.top_radius = 0.8
	cilindro_mesh.bottom_radius = 0.8
	cilindro_mesh.height = 1.6
	_malla.mesh = cilindro_mesh
	add_child(_malla)

	# Núcleo brillante
	_nucleo = MeshInstance3D.new()
	var esfera_mesh := SphereMesh.new()
	esfera_mesh.radius = 0.5
	esfera_mesh.height = 1.0
	_nucleo.mesh = esfera_mesh
	add_child(_nucleo)

	# Luz omnidireccional
	_luz = OmniLight3D.new()
	_luz.omni_range = 5.0
	add_child(_luz)

	_actualizar_materiales()

func _actualizar_materiales() -> void:
	var color_base := Color(0.8, 0.2, 1.0, 0.8) if es_morado else Color(0.1, 0.6, 1.0, 0.8)
	var color_emision := Color(0.7, 0.1, 1.0) if es_morado else Color(0.1, 0.7, 1.0)

	var mat_ext := StandardMaterial3D.new()
	mat_ext.albedo_color = color_base
	mat_ext.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ext.emission_enabled = true
	mat_ext.emission = color_emision
	mat_ext.emission_energy_multiplier = 3.0
	_malla.material_override = mat_ext

	var mat_int := StandardMaterial3D.new()
	mat_int.albedo_color = color_emision
	mat_int.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_int.emission_enabled = true
	mat_int.emission = color_emision
	mat_int.emission_energy_multiplier = 5.0
	_nucleo.material_override = mat_int

	_luz.light_color = color_emision
	_luz.light_energy = 2.0

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = 0.9
	forma.height = 1.8
	col.shape = forma
	col.position.y = _altura_base
	add_child(col)

func _process(delta: float) -> void:
	if not _disponible:
		_tiempo_espera -= delta
		if _tiempo_espera <= 0.0:
			_reaparecer()
		return

	_angulo += delta * 3.0
	_malla.rotation.y = _angulo
	_nucleo.rotation.y = -_angulo * 2.0
	
	var flotar := sin(_angulo * 1.5) * 0.3
	_malla.position.y = _altura_base + flotar
	_nucleo.position.y = _altura_base + flotar
	_luz.position.y = _altura_base + flotar

func _al_entrar_cuerpo(cuerpo: Node3D) -> void:
	_intentar_recoger(cuerpo)

func _al_entrar_area(area: Area3D) -> void:
	_intentar_recoger(area.get_parent())

func _intentar_recoger(nodo: Node) -> void:
	if not _disponible or nodo == null:
		return

	if (nodo.is_in_group("jugador") or nodo.is_in_group("rivales")) and nodo.has_method("recibir_nitro"):
		nodo.recibir_nitro(recarga_porcentaje)
		_desactivar()

func _desactivar() -> void:
	_disponible = false
	_tiempo_espera = tiempo_reaparicion
	_malla.visible = false
	_nucleo.visible = false
	_luz.visible = false
	set_deferred("monitoring", false)
	_efecto_recogida()

func _reaparecer() -> void:
	_disponible = true
	_malla.visible = true
	_nucleo.visible = true
	_luz.visible = true
	set_deferred("monitoring", true)
	
	_malla.scale = Vector3.ZERO
	_nucleo.scale = Vector3.ZERO
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_malla, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_nucleo, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _efecto_recogida() -> void:
	var destello := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	destello.mesh = sm
	var mat := StandardMaterial3D.new()
	var col_dest := Color(0.8, 0.2, 1.0) if es_morado else Color(0.1, 0.7, 1.0)
	mat.albedo_color = col_dest
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = col_dest
	mat.emission_energy_multiplier = 6.0
	destello.material_override = mat
	get_parent().add_child(destello)
	destello.global_position = global_position + Vector3(0, _altura_base, 0)
	
	var tw := destello.create_tween()
	tw.set_parallel(true)
	tw.tween_property(destello, "scale", Vector3.ONE * 3.0, 0.3)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tw.chain().tween_callback(destello.queue_free)
