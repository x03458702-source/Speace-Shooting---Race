class_name CajaComodin
extends Area3D
## Caja de Comodín (RF-08)
## Flota sobre la pista, gira continuamente y otorga un comodín aleatorio
## al competidor (jugador o IA) que no tenga ninguno almacenado.
## Reaparece cada 15-20 segundos.

@export var tiempo_reaparicion: float = 16.0

var _malla_caja: MeshInstance3D
var _nucleo: MeshInstance3D
var _luz: OmniLight3D
var _disponible: bool = true
var _tiempo_espera: float = 0.0
var _altura_base: float = 2.2
var _angulo: float = 0.0

func _ready() -> void:
	collision_layer = 8       # Capa 4 (Cajas)
	collision_mask = 1 | 2    # Jugador y Rivales (Capa 1 y Capa 2)
	_construir_visuales()
	_crear_colision()
	body_entered.connect(_al_entrar_cuerpo)
	area_entered.connect(_al_entrar_area)

func _construir_visuales() -> void:
	# Caja exterior holográfica semi-transparente
	_malla_caja = MeshInstance3D.new()
	var caja_mesh := BoxMesh.new()
	caja_mesh.size = Vector3(2.0, 2.0, 2.0)
	_malla_caja.mesh = caja_mesh
	
	var mat_ext := StandardMaterial3D.new()
	mat_ext.albedo_color = Color(1.0, 0.85, 0.2, 0.4)
	mat_ext.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_ext.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_ext.emission_enabled = true
	mat_ext.emission = Color(1.0, 0.7, 0.1)
	mat_ext.emission_energy_multiplier = 2.5
	_malla_caja.material_override = mat_ext
	add_child(_malla_caja)

	# Núcleo interior brillante
	_nucleo = MeshInstance3D.new()
	var nucleo_mesh := BoxMesh.new()
	nucleo_mesh.size = Vector3(1.1, 1.1, 1.1)
	_nucleo.mesh = nucleo_mesh
	
	var mat_int := StandardMaterial3D.new()
	mat_int.albedo_color = Color(0.2, 0.9, 1.0)
	mat_int.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_int.emission_enabled = true
	mat_int.emission = Color(0.2, 0.9, 1.0)
	mat_int.emission_energy_multiplier = 4.0
	_nucleo.material_override = mat_int
	add_child(_nucleo)

	# Luz omnidireccional
	_luz = OmniLight3D.new()
	_luz.light_color = Color(1.0, 0.85, 0.3)
	_luz.light_energy = 1.5
	_luz.omni_range = 6.0
	add_child(_luz)

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.5, 2.5, 2.5)
	col.shape = forma
	# La caja flota a _altura_base (2.2): la colisión debe estar a la misma
	# altura que los visuales, si no nunca solapa con la nave (y≈2.6).
	col.position.y = _altura_base
	add_child(col)

func _process(delta: float) -> void:
	if not _disponible:
		_tiempo_espera -= delta
		if _tiempo_espera <= 0.0:
			_reaparecer()
		return

	# Giro continuo y flotación suave
	_angulo += delta * 2.5
	_malla_caja.rotation.y = _angulo
	_malla_caja.rotation.x = sin(_angulo * 0.7) * 0.3
	_nucleo.rotation.y = -_angulo * 1.5
	_nucleo.rotation.z = cos(_angulo * 0.9) * 0.4
	
	var flotar := sin(_angulo * 1.8) * 0.35
	_malla_caja.position.y = _altura_base + flotar
	_nucleo.position.y = _altura_base + flotar
	_luz.position.y = _altura_base + flotar

func _al_entrar_cuerpo(cuerpo: Node3D) -> void:
	_intentar_recoger(cuerpo)

func _al_entrar_area(area: Area3D) -> void:
	_intentar_recoger(area.get_parent())

func _intentar_recoger(nodo: Node) -> void:
	if not _disponible or nodo == null:
		return

	# Comprueba si el nodo es una nave (Jugador o IA) con método recibir_comodin
	if nodo.has_method("recibir_comodin"):
		var recogido: bool = nodo.recibir_comodin(PowerUpTypes.obtener_aleatorio())
		if recogido:
			if nodo.is_in_group("jugador"):
				var rm := get_tree().root.find_child("RaceManager", true, false)
				if rm != null and rm.has_method("sumar_puntos_jugador"):
					rm.sumar_puntos_jugador(50)
			_desactivar()

func _desactivar() -> void:
	_disponible = false
	_tiempo_espera = tiempo_reaparicion
	_malla_caja.visible = false
	_nucleo.visible = false
	_luz.visible = false
	set_deferred("monitoring", false)
	_efecto_recogida()

func _reaparecer() -> void:
	_disponible = true
	_malla_caja.visible = true
	_nucleo.visible = true
	_luz.visible = true
	set_deferred("monitoring", true)
	
	# Animación de escala al reaparecer
	_malla_caja.scale = Vector3.ZERO
	_nucleo.scale = Vector3.ZERO
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_malla_caja, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_nucleo, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _efecto_recogida() -> void:
	var destello := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 1.2
	destello.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.9, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 5.0
	destello.material_override = mat
	get_parent().add_child(destello)
	destello.global_position = global_position + Vector3(0, _altura_base, 0)
	
	var tw := destello.create_tween()
	tw.set_parallel(true)
	tw.tween_property(destello, "scale", Vector3.ONE * 3.5, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(destello.queue_free)
