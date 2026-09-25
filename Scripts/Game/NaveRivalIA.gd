class_name NaveRivalIA
extends CharacterBody3D
## NAVE RIVAL IA (Sección 10, 16 y 20)
## Piloto rival autónomo con navegación por spline de circuito,
## evasión de obstáculos, recolección de comodines y uso táctico de habilidades.

signal vidas_cambiadas(vidas_actuales: int, vidas_max: int)
signal nave_destruida()
signal vuelta_completada(vuelta: int, total_vueltas: int)

@export var nombre_piloto: String = "Rival"
@export var color_primario: Color = Color(0.85, 0.15, 0.15)
@export var color_secundario: Color = Color(0.95, 0.8, 0.1)
@export var color_energia: Color = Color(1.0, 0.4, 0.1)

@export var avance_base: float = 27.5
@export var agresividad: float = 0.5   # 0 a 1
@export var medio_ancho: float = 20.0
@export var altura_circuito: float = 2.6
@export var total_vueltas_carrera: int = 3

var vidas: int = 3
var max_vidas: int = 3
var vueltas: int = 0
var progreso_total: float = 0.0
var control_habilitado: bool = true

# Comodines
var comodin_almacenado: int = PowerUpTypes.Type.NONE
var cargas_canon: int = 0
var escudo_activo: bool = false
var tiempo_escudo: float = 0.0
var _tiempo_decision_comodin: float = 1.0

# Efectos temporales
var _ralentizado_tiempo: float = 0.0
var _ralentizado_factor: float = 1.0
var _giro_aceite_tiempo: float = 0.0
var _giro_aceite_acum: float = 0.0
var _empuje_lateral: float = 0.0
var _tiempo_inmune: float = 0.0

# Seguimiento de circuito
var modelo: Node3D
var llamas: Array[Node3D] = []
var _malla_escudo: MeshInstance3D
var _lat: float = 0.0
var _lat_objetivo: float = 0.0
var _tiempo_cambio_carril: float = 2.0
var _pp := PackedVector3Array()
var _pw := PackedFloat32Array()
var _pc := PackedFloat32Array()
var _ptotal := 0.0
var _s := 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 2       # Capa 2: Rivales
	collision_mask = 4 | 8 | 16
	add_to_group("rivales")
	
	vidas = max_vidas
	
	modelo = Node3D.new()
	modelo.name = "Modelo"
	add_child(modelo)
	
	_construir_nave()
	_construir_escudo()
	_crear_colision()

func cargar_circuito(puntos: PackedVector3Array, anchos: PackedFloat32Array, s_inicial: float, lat_inicial: float) -> void:
	_pp = puntos
	_pw = anchos
	_pc.clear()
	_pc.append(0.0)
	var acc := 0.0
	var n := _pp.size()
	for i in n:
		acc += _pp[i].distance_to(_pp[(i + 1) % n])
		_pc.append(acc)
	_ptotal = acc
	_s = s_inicial
	_lat = lat_inicial
	_lat_objetivo = lat_inicial
	_snap_circuito()

func _punto_en(s: float) -> Array:
	var n := _pp.size()
	if n == 0 or _ptotal <= 0.0:
		return [global_position, -global_transform.basis.z, 20.0]
	var ss := fposmod(s, _ptotal)
	var i := 0
	while i < n - 1 and _pc[i + 1] <= ss:
		i += 1
	var a := _pc[i]
	var b := _pc[i + 1]
	var f := 0.0
	if b > a:
		f = (ss - a) / (b - a)
	var p0 := _pp[i]
	var p1 := _pp[(i + 1) % n]
	var tan := p1 - p0
	if tan.length() < 0.001:
		tan = Vector3(0, 0, 1)
	else:
		tan = tan.normalized()
	return [p0.lerp(p1, f), tan, lerpf(_pw[i], _pw[(i + 1) % n], f)]

func _snap_circuito() -> void:
	var m := _punto_en(_s)
	var centro: Vector3 = m[0]
	var t: Vector3 = m[1]
	var right := Vector3(-t.z, 0.0, t.x)
	global_position = centro + right * _lat + Vector3(0.0, altura_circuito, 0.0)
	rotation.y = atan2(-t.x, -t.z)
	rotation.x = 0.0
	velocity = t * avance_base

func _physics_process(delta: float) -> void:
	_actualizar_efectos(delta)

	if control_habilitado:
		_pensar_ia(delta)
		_proceso_circuito(delta)
	else:
		velocity = Vector3.ZERO

	# Inclinación y efectos de giro
	if _giro_aceite_tiempo > 0.0:
		modelo.rotation.y = _giro_aceite_acum

	var fuerza := 1.0 + velocity.length() * 0.03
	for llama in llamas:
		llama.scale.z = fuerza * randf_range(0.8, 1.2)

func _pensar_ia(delta: float) -> void:
	# 1. Cambio de carril y evasión periódica
	_tiempo_cambio_carril -= delta
	if _tiempo_cambio_carril <= 0.0:
		_tiempo_cambio_carril = randf_range(1.5, 3.5)
		# Preferencia de carril con variación aleatoria
		_lat_objetivo = randf_range(-medio_ancho * 0.65, medio_ancho * 0.65)

	# 2. Detección frontal de obstáculos en la pista (Asteroides y Barreras)
	_evaluar_evasion_obstaculos()

	# 3. Decisión táctica de uso de comodines
	_tiempo_decision_comodin -= delta
	if _tiempo_decision_comodin <= 0.0:
		_tiempo_decision_comodin = randf_range(0.8, 1.8)
		_evaluar_uso_comodin()

func _evaluar_evasion_obstaculos() -> void:
	# Muestreo hacia adelante en el circuito (distancia de anticipación 35 m,
	# coherente con el umbral de 28 m usado abajo).
	var obstaculos := get_tree().get_nodes_in_group("obstaculos")
	for obs in obstaculos:
		if is_instance_valid(obs) and obs is Node3D:
			var dist: float = global_position.distance_to(obs.global_position)
			if dist < 28.0:
				# Si el obstáculo está adelante, esquiva hacia el lado contrario
				var dir_rel := to_local(obs.global_position)
				if dir_rel.z < 0: # Delante
					if dir_rel.x > 0:
						_lat_objetivo = -medio_ancho * 0.7
					else:
						_lat_objetivo = medio_ancho * 0.7

func _evaluar_uso_comodin() -> void:
	if comodin_almacenado == PowerUpTypes.Type.NONE:
		return

	match comodin_almacenado:
		PowerUpTypes.Type.ESCUDO:
			# Activa escudo si hay obstáculos cercanos o si va en zona estrecha
			activar_escudo()
			comodin_almacenado = PowerUpTypes.Type.NONE

		PowerUpTypes.Type.CANON:
			# Dispara cañón hacia el frente si hay competidores u obstáculos
			_disparar_canon_ia()
			cargas_canon -= 1
			if cargas_canon <= 0:
				comodin_almacenado = PowerUpTypes.Type.NONE

		PowerUpTypes.Type.BOMBA:
			# Detona si hay competidores en radio de 25 metros
			var cerca := false
			var jugador := get_tree().get_first_node_in_group("jugador")
			if jugador != null and global_position.distance_to(jugador.global_position) < 26.0:
				cerca = true
			if cerca or randf() < 0.35:
				_detonar_bomba_ia()
				comodin_almacenado = PowerUpTypes.Type.NONE

		PowerUpTypes.Type.ACEITE:
			# Coloca trampa si alguien viene detrás
			var alguien_detras := false
			var jugador := get_tree().get_first_node_in_group("jugador")
			if jugador != null:
				var rel := to_local(jugador.global_position)
				if rel.z > 0 and rel.length() < 30.0:
					alguien_detras = true
			if alguien_detras or randf() < 0.4:
				_soltar_aceite_ia()
				comodin_almacenado = PowerUpTypes.Type.NONE

func _proceso_circuito(delta: float) -> void:
	var adelante := _punto_en(_s + 40.0)[1] as Vector3
	var m := _punto_en(_s)
	var centro: Vector3 = m[0]
	var t: Vector3 = m[1]
	var w := float(m[2])
	var giro := t.angle_to(adelante) / PI

	var v_base := avance_base * (1.0 - 0.22 * clampf(giro * 2.0, 0.0, 1.0))
	var v := v_base * _ralentizado_factor if control_habilitado else 0.0
	_s += v * delta

	progreso_total = vueltas * _ptotal + _s

	if _s >= _ptotal and _ptotal > 0.0:
		_s -= _ptotal
		vueltas += 1
		emit_signal("vuelta_completada", vueltas, total_vueltas_carrera)

	m = _punto_en(_s)
	centro = m[0]
	t = m[1]
	w = float(m[2])
	var right := Vector3(-t.z, 0.0, t.x)
	var mitad := minf(medio_ancho, maxf(w * 0.5 - 2.5, 4.0))

	_lat = lerpf(_lat, _lat_objetivo + _empuje_lateral, 1.0 - exp(-2.2 * delta))
	_lat = clampf(_lat, -mitad, mitad)
	_empuje_lateral = lerpf(_empuje_lateral, 0.0, 1.0 - exp(-3.0 * delta))

	global_position = centro + right * _lat + Vector3(0.0, altura_circuito, 0.0)

	var yaw_obj := atan2(-t.x, -t.z)
	rotation.y = lerp_angle(rotation.y, yaw_obj, 1.0 - exp(-5.0 * delta))
	velocity = t * v

func _actualizar_efectos(delta: float) -> void:
	if _tiempo_inmune > 0.0:
		_tiempo_inmune -= delta
		modelo.visible = int(Time.get_ticks_msec() / 80) % 2 == 0
		if _tiempo_inmune <= 0.0:
			modelo.visible = true

	if escudo_activo:
		tiempo_escudo -= delta
		if tiempo_escudo <= 0.0:
			desactivar_escudo()

	if _ralentizado_tiempo > 0.0:
		_ralentizado_tiempo -= delta
		if _ralentizado_tiempo <= 0.0:
			_ralentizado_factor = 1.0

	if _giro_aceite_tiempo > 0.0:
		_giro_aceite_tiempo -= delta
		_giro_aceite_acum += delta * TAU * 2.5
		if _giro_aceite_tiempo <= 0.0:
			modelo.rotation.y = 0.0

# ---------------------------------------------------------------
# COMODINES IA
# ---------------------------------------------------------------
func recibir_comodin(tipo: int) -> bool:
	if comodin_almacenado != PowerUpTypes.Type.NONE:
		return false
	comodin_almacenado = tipo
	if tipo == PowerUpTypes.Type.CANON:
		cargas_canon = 3
	return true

func activar_escudo() -> void:
	escudo_activo = true
	tiempo_escudo = 8.0
	_malla_escudo.visible = true

func desactivar_escudo() -> void:
	escudo_activo = false
	tiempo_escudo = 0.0
	_malla_escudo.visible = false

func _disparar_canon_ia() -> void:
	var padre := get_parent()
	if padre == null: return
	var dir_tiro := -global_transform.basis.z
	var laser := Node3D.new()
	laser.set_script(load("res://laser.gd"))
	laser.set("tirador", self)
	laser.set("es_del_jugador", false)
	laser.set("es_comodin_canon", true)
	padre.add_child(laser)
	laser.global_position = to_global(Vector3(0.0, 0.0, -2.8))
	laser.global_transform = Transform3D(Basis.looking_at(dir_tiro.normalized()), laser.global_position)

func _detonar_bomba_ia() -> void:
	var padre := get_parent()
	if padre == null: return
	var bomba := OndaBomba.new()
	bomba.creador = self
	bomba.es_jugador = false
	padre.add_child(bomba)
	bomba.global_position = global_position

func _soltar_aceite_ia() -> void:
	var padre := get_parent()
	if padre == null: return
	var trampa := TrampaAceite.new()
	trampa.creador = self
	padre.add_child(trampa)
	trampa.global_position = global_position - global_transform.basis.z * -3.5 + Vector3(0, -altura_circuito + 0.1, 0)

# ---------------------------------------------------------------
# SALUD Y COMBATE IA
# ---------------------------------------------------------------
func recibir_dano(cantidad: int, _origen: Vector3 = Vector3.ZERO) -> void:
	if _tiempo_inmune > 0.0 or vidas <= 0:
		return
	if escudo_activo:
		desactivar_escudo()
		return
	vidas = max(0, vidas - cantidad)
	emit_signal("vidas_cambiadas", vidas, max_vidas)
	if vidas <= 0:
		_destruir_ia()
	else:
		_tiempo_inmune = 1.5

func recibir_impacto_laser(es_canon: bool, _es_del_jugador: bool) -> void:
	if escudo_activo:
		desactivar_escudo()
		return
	aplicar_ralentizacion(0.40 if es_canon else 0.20, 2.0 if es_canon else 1.0)

func recibir_impacto_bomba(direccion: Vector3) -> void:
	if escudo_activo:
		desactivar_escudo()
		return
	_empuje_lateral += direccion.x * 12.0
	aplicar_ralentizacion(0.50, 1.5)

func aplicar_ralentizacion(reduccion: float, duracion: float) -> void:
	_ralentizado_factor = 1.0 - reduccion
	_ralentizado_tiempo = duracion

func aplicar_giro_aceite(duracion: float, reduccion: float) -> void:
	if escudo_activo:
		desactivar_escudo()
		return
	_giro_aceite_tiempo = duracion
	_giro_aceite_acum = 0.0
	aplicar_ralentizacion(reduccion, duracion)

func _destruir_ia() -> void:
	control_habilitado = false
	modelo.visible = false
	emit_signal("nave_destruida")

# ---------------------------------------------------------------
# CONSTRUCCIÓN PROCEDURAL DE LA NAVE RIVAL
# ---------------------------------------------------------------
func _construir_escudo() -> void:
	_malla_escudo = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.5
	sm.height = 7.0
	_malla_escudo.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color_energia.r, color_energia.g, color_energia.b, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = color_energia
	mat.emission_energy_multiplier = 3.5
	_malla_escudo.material_override = mat
	_malla_escudo.visible = false
	add_child(_malla_escudo)

func _crear_colision() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.6, 1.2, 5.6)
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3(0.0, 0.0, -0.8)
	add_child(col)

func _mat(color: Color, metal: float = 0.4, rugosidad: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rugosidad
	return m

func _caja(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b

func _cilindro(radio_arriba: float, radio_abajo: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radio_arriba
	c.bottom_radius = radio_abajo
	c.height = alto
	c.radial_segments = 20
	return c

func _pieza(malla: Mesh, mat: Material, pos: Vector3, rot_grados: Vector3 = Vector3.ZERO, padre: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_grados
	if padre == null:
		padre = modelo
	padre.add_child(mi)
	return mi

func _construir_nave() -> void:
	var m_primario := _mat(color_primario, 0.4, 0.4)
	var m_secundario := _mat(color_secundario, 0.7, 0.3)
	var oscuro := _mat(Color(0.12, 0.12, 0.15), 0.6, 0.4)

	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(color_energia.r, color_energia.g, color_energia.b, 0.6)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.metallic = 0.6
	cristal.emission_enabled = true
	cristal.emission = color_energia
	cristal.emission_energy_multiplier = 0.8

	var fuego := StandardMaterial3D.new()
	fuego.albedo_color = Color(color_energia.r, color_energia.g, color_energia.b, 0.7)
	fuego.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.emission_enabled = true
	fuego.emission = color_energia
	fuego.emission_energy_multiplier = 2.5

	# Cuerpo
	_pieza(_caja(Vector3(1.4, 0.5, 4.0)), m_primario, Vector3(0.0, 0.0, 0.0))
	var punta := PrismMesh.new()
	punta.size = Vector3(1.4, 1.8, 0.5)
	_pieza(punta, m_primario, Vector3(0.0, 0.0, -2.9), Vector3(-90.0, 0.0, 0.0))
	_pieza(_caja(Vector3(0.35, 0.03, 0.7)), m_secundario, Vector3(0.0, 0.26, -2.4))
	_pieza(_caja(Vector3(0.6, 0.1, 2.0)), oscuro, Vector3(0.0, -0.27, 0.3))

	# Cabina
	_pieza(_caja(Vector3(0.8, 0.35, 1.5)), cristal, Vector3(0.0, 0.35, -0.7))

	# Alas y Aletas
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var giro := -lado * 25.0
		var base := Basis(Vector3.UP, deg_to_rad(giro))
		var centro := Vector3(lado * 2.0, -0.1, 0.9)
		_pieza(_caja(Vector3(2.8, 0.08, 1.4)), m_primario, centro, Vector3(0.0, giro, 0.0))
		_pieza(_caja(Vector3(0.15, 0.1, 1.2)), m_secundario, centro + base * Vector3(lado * 1.4, 0.0, 0.0), Vector3(0.0, giro, 0.0))

		var aleta := _pieza(_caja(Vector3(0.08, 1.1, 0.9)), m_primario, Vector3(lado * 1.15, 0.75, 1.3), Vector3(20.0, 0.0, -lado * 12.0))
		_pieza(_caja(Vector3(0.1, 0.25, 0.9)), m_secundario, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, aleta)

	# Motores
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var x := lado * 1.0
		_pieza(_cilindro(0.36, 0.36, 2.0), oscuro, Vector3(x, 0.0, 1.0), Vector3(90.0, 0.0, 0.0))
		
		var pivote := Node3D.new()
		pivote.position = Vector3(x, 0.0, 2.03)
		modelo.add_child(pivote)
		_pieza(_cilindro(0.0, 0.2, 0.9), fuego, Vector3(0.0, 0.0, 0.45), Vector3(90.0, 0.0, 0.0), pivote)
		llamas.append(pivote)
