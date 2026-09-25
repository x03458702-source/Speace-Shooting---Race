class_name TrampaAceite
extends Area3D
## Trampa de Aceite Espacial (RF-13)
## Se coloca sobre la pista detrás de la nave.
## Al ser pisada por un competidor, provoca giro forzado y reduce un 60% la velocidad durante 2.5 s.

@export var duracion_efecto: float = 2.5
@export var reduccion_velocidad: float = 0.60
@export var vida_maxima: float = 60.0

var creador: Node = null
var _tiempo_inmune_creador: float = 0.8
var _malla: MeshInstance3D
var _anillo: MeshInstance3D

func _ready() -> void:
	collision_layer = 16       # Capa 5 (Trampas)
	collision_mask = 1 | 2     # Jugador y Rivales (Capa 1 y Capa 2)
	_construir_visuales()
	_crear_colision()
	body_entered.connect(_al_entrar_cuerpo)
	area_entered.connect(_al_entrar_area)

func _construir_visuales() -> void:
	# Charco viscoso púrpura/oscuro
	_malla = MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 2.8
	disco.bottom_radius = 3.2
	disco.height = 0.08
	_malla.mesh = disco
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.02, 0.22, 0.92)
	mat.metallic = 0.8
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.1, 0.8)
	mat.emission_energy_multiplier = 1.8
	_malla.material_override = mat
	_malla.position.y = 0.05
	add_child(_malla)

	# Borde/anillo luminoso de energía inestable
	_anillo = MeshInstance3D.new()
	var aro := TorusMesh.new()
	aro.inner_radius = 2.7
	aro.outer_radius = 3.1
	_anillo.mesh = aro
	var mat_aro := StandardMaterial3D.new()
	mat_aro.albedo_color = Color(0.8, 0.2, 1.0)
	mat_aro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_aro.emission_enabled = true
	mat_aro.emission = Color(0.85, 0.25, 1.0)
	mat_aro.emission_energy_multiplier = 3.0
	_anillo.material_override = mat_aro
	_anillo.position.y = 0.06
	add_child(_anillo)

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	var forma := CylinderShape3D.new()
	forma.radius = 3.0
	forma.height = 1.0
	col.shape = forma
	col.position.y = 0.5
	add_child(col)

func _process(delta: float) -> void:
	if _tiempo_inmune_creador > 0.0:
		_tiempo_inmune_creador -= delta

	vida_maxima -= delta
	if vida_maxima <= 0.0:
		queue_free()
		return

	# Pulso suave en el borde del aceite
	var s := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.05
	_anillo.scale = Vector3(s, 1.0, s)

func _al_entrar_cuerpo(cuerpo: Node3D) -> void:
	_activar_trampa(cuerpo)

func _al_entrar_area(area: Area3D) -> void:
	_activar_trampa(area.get_parent())

func _activar_trampa(nodo: Node) -> void:
	if nodo == null:
		return
	if nodo == creador and _tiempo_inmune_creador > 0.0:
		return

	if nodo.has_method("aplicar_giro_aceite"):
		nodo.aplicar_giro_aceite(duracion_efecto, reduccion_velocidad)
		if creador != null and creador.is_in_group("jugador") and nodo.is_in_group("rivales"):
			var rm := get_tree().root.find_child("RaceManager", true, false)
			if rm != null and rm.has_method("sumar_puntos_jugador"):
				rm.sumar_puntos_jugador(150)
		_efecto_salpicadura()
		queue_free()

func _efecto_salpicadura() -> void:
	var efecto := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.2
	sm.height = 2.4
	efecto.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.2, 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.25, 1.0)
	mat.emission_energy_multiplier = 4.0
	efecto.material_override = mat
	get_parent().add_child(efecto)
	efecto.global_position = global_position + Vector3(0, 0.5, 0)
	
	var tw := efecto.create_tween()
	tw.set_parallel(true)
	tw.tween_property(efecto, "scale", Vector3(3.0, 0.5, 3.0), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.chain().tween_callback(efecto.queue_free)
