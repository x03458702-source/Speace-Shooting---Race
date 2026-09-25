extends CharacterBody3D
## NAVE ESPACIAL 3D (Godot 4) - Space Shooting-Race
## Modelo 3D procedural sci-fi, seguimiento de circuito, inventario de comodines (máx 1),
## sistema de 3 vidas, escudo energético, disparos de cañón y efectos de combate.

signal vidas_cambiadas(vidas_actuales: int, vidas_max: int)
signal comodin_cambiado(tipo_comodin: int, cargas: int)
signal nave_destruida()
signal vuelta_completada(vuelta: int, total_vueltas: int)

# ---------------------------------------------------------------
# AJUSTES
# ---------------------------------------------------------------
@export_group("Movimiento")
@export var velocidad: float = 5.0
@export var suavidad: float = 8.0
@export var limite_x: float = 7.0
@export var limite_y: float = 4.0
@export var inclinacion: float = 0.5

@export_group("Carrera")
@export var auto_avanzar: bool = true
@export var avance: float = 28.0
@export var limite_z_min: float = -960.0
@export var limite_z_max: float = 960.0
@export var vueltas: int = 0
@export var total_vueltas_carrera: int = 3

@export_group("Circuito en V")
@export var modo_circuito: bool = false
@export var altura_circuito: float = 2.6
@export var medio_ancho: float = 20.0

@export_group("Combate y Salud")
@export var max_vidas: int = 3
@export var tiempo_invulnerabilidad: float = 1.5

@export_group("Disparo")
@export var cadencia: float = 0.18

@export_group("Cámara y Luz")
@export var crear_camara: bool = true
@export var crear_luz: bool = true

# ---------------------------------------------------------------
# VARIABLES DE ESTADO Y COMBATE
# ---------------------------------------------------------------
var vidas: int = 3
var inmune: bool = false
var tiempo_inmune: float = 0.0
var control_habilitado: bool = true
var comodin_almacenado: int = PowerUpTypes.Type.NONE
var cargas_canon: int = 0
var escudo_activo: bool = false
var tiempo_escudo: float = 0.0
var progreso_total: float = 0.0

# Efectos de estado
var _ralentizado_tiempo: float = 0.0
var _ralentizado_factor: float = 1.0
var _giro_aceite_tiempo: float = 0.0
var _giro_aceite_acum: float = 0.0
var _empuje_lateral: float = 0.0

# Visuales y circuito
var modelo: Node3D
var llamas: Array[Node3D] = []
var _malla_escudo: MeshInstance3D
var _tiempo_disparo: float = 0.0
var _tiempo_uso_comodin: float = 0.0
var _lat: float = 0.0
var _alt: float = 0.0
var _bank_extra: float = 0.0
var _cam: Camera3D
var _cam_yaw: float = 0.0
var _pp := PackedVector3Array()
var _pw := PackedFloat32Array()
var _pc := PackedFloat32Array()
var _ptotal := 0.0
var _s := 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1       # Capa 1: Jugador
	collision_mask = 4 | 8 | 16
	add_to_group("jugador")

	vidas = max_vidas

	modelo = Node3D.new()
	modelo.name = "Modelo"
	add_child(modelo)

	_construir_nave()
	_construir_escudo()
	_crear_colision()

	if crear_luz:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		luz.light_energy = 1.3
		add_child(luz)

	if crear_camara:
		if modo_circuito:
			_cam = Camera3D.new()
			_cam.top_level = true
			add_child(_cam)
			_cam.current = true
			_cam.fov = 70.0
			_cam_yaw = rotation.y
		else:
			var camara := Camera3D.new()
			add_child(camara)
			camara.position = Vector3(0.0, 2.0, 11.0)
			camara.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
			camara.current = true

	if modo_circuito:
		_s = 0.0
		_lat = 0.0
		_alt = 0.0
		_snap_circuito()
		_actualizar_camara(1.0 / 60.0, true)

	emit_signal("vidas_cambiadas", vidas, max_vidas)
	emit_signal("comodin_cambiado", comodin_almacenado, cargas_canon)

func cargar_circuito(puntos: PackedVector3Array, anchos: PackedFloat32Array) -> void:
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
	_s = 0.0
	_lat = 0.0
	_alt = 0.0
	modo_circuito = true
	auto_avanzar = true
	if is_node_ready():
		_snap_circuito()
		_actualizar_camara(1.0 / 60.0, true)

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
	velocity = t * avance

func _physics_process(delta: float) -> void:
	_actualizar_efectos_temporales(delta)

	var dir := _leer_direccion() if control_habilitado else Vector2.ZERO

	if modo_circuito:
		_proceso_circuito(delta, dir)
	else:
		_movimiento_recto(delta, dir)

	# Inclinación al doblar + giro si pisó aceite
	var t := 1.0 - exp(-6.0 * delta)
	modelo.rotation.z = lerpf(modelo.rotation.z, -dir.x * inclinacion + _bank_extra, t)
	modelo.rotation.x = lerpf(modelo.rotation.x, dir.y * inclinacion * 0.5, t)
	if _giro_aceite_tiempo > 0.0:
		modelo.rotation.y = _giro_aceite_acum

	# Llamas de los motores
	var fuerza := 1.0 + velocity.length() * 0.03
	for llama in llamas:
		llama.scale.z = fuerza * randf_range(0.8, 1.2)

	# Entrada de disparos
	_tiempo_disparo -= delta
	_tiempo_uso_comodin -= delta

	if control_habilitado:
		# Disparo normal (Láser primario: Clic izq / J / Ctrl)
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_CTRL)) and _tiempo_disparo <= 0.0:
			_disparar_laser_normal()
			_tiempo_disparo = cadencia

		# Activar comodín (Espacio / Clic der / E)
		if (Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_E)) and _tiempo_uso_comodin <= 0.0:
			usar_comodin()
			_tiempo_uso_comodin = 0.25

func _proceso_circuito(delta: float, dir: Vector2) -> void:
	var adelante := _punto_en(_s + 40.0)[1] as Vector3
	var m := _punto_en(_s)
	var centro: Vector3 = m[0]
	var t: Vector3 = m[1]
	var w := float(m[2])
	var giro := t.angle_to(adelante) / PI
	
	var v_base := avance * (1.0 - 0.25 * clampf(giro * 2.0, 0.0, 1.0))
	var v := v_base * _ralentizado_factor if (auto_avanzar and control_habilitado) else 0.0
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
	var mitad := minf(medio_ancho, maxf(w * 0.5 - 2.0, 4.0))
	
	# Desplazamiento lateral con control + empuje de bomba
	_lat = lerpf(_lat, dir.x * medio_ancho + _empuje_lateral, 1.0 - exp(-1.8 * delta))
	_lat = clampf(_lat, -mitad, mitad)
	_empuje_lateral = lerpf(_empuje_lateral, 0.0, 1.0 - exp(-3.0 * delta))
	
	_alt = lerpf(_alt, dir.y * 10.0, 1.0 - exp(-1.2 * delta))
	var cy := clampf(altura_circuito + _alt, 1.6, 24.0)
	global_position = centro + right * _lat + Vector3(0.0, cy, 0.0)

	var yaw_obj := atan2(-t.x, -t.z)
	var yaw_rate := angle_difference(rotation.y, yaw_obj) / maxf(delta, 0.0001)
	rotation.y = lerp_angle(rotation.y, yaw_obj, 1.0 - exp(-5.0 * delta))
	rotation.x = lerpf(rotation.x, dir.y * 0.25, 1.0 - exp(-3.0 * delta))
	_bank_extra = clampf(-yaw_rate * 0.25, -0.45, 0.45)
	velocity = t * v
	_actualizar_camara(delta, false)

func _movimiento_recto(delta: float, dir: Vector2) -> void:
	_bank_extra = 0.0
	var vz := -avance * _ralentizado_factor if (auto_avanzar and control_habilitado) else 0.0
	var objetivo := Vector3(dir.x * velocidad, dir.y * velocidad, vz)
	velocity = velocity.lerp(objetivo, 1.0 - exp(-suavidad * delta))
	move_and_slide()
	position.x = clampf(position.x, -limite_x, limite_x)
	position.y = clampf(position.y, -limite_y, limite_y)
	if position.z <= limite_z_min:
		position.z = limite_z_max
		vueltas += 1
		emit_signal("vuelta_completada", vueltas, total_vueltas_carrera)
	else:
		position.z = clampf(position.z, limite_z_min, limite_z_max)

func _actualizar_camara(delta: float, instantaneo: bool) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	if not instantaneo:
		_cam_yaw = lerp_angle(_cam_yaw, rotation.y, 1.0 - exp(-2.2 * delta))
	else:
		_cam_yaw = rotation.y
	var adelante := Vector3(-sin(_cam_yaw), 0.0, -cos(_cam_yaw))
	var lado_c := Vector3(-adelante.z, 0.0, adelante.x)
	var objetivo := global_position - adelante * 12.0 + Vector3(0.0, 2.6, 0.0) - lado_c * _lat * 0.45
	if instantaneo:
		_cam.global_position = objetivo
	else:
		_cam.global_position = _cam.global_position.lerp(objetivo, 1.0 - exp(-6.0 * delta))
	var mirar := global_position + Vector3(0.0, 1.0, 0.0) + adelante * 10.0
	var actual := _cam.global_transform
	var deseo := actual.looking_at(mirar, Vector3.UP)
	if instantaneo:
		_cam.global_transform = deseo
	else:
		_cam.global_transform = actual.interpolate_with(deseo, 1.0 - exp(-8.0 * delta))
	var fov_obj := 68.0 + 5.0 * clampf(velocity.length() / maxf(avance, 1.0), 0.0, 1.2)
	_cam.fov = fov_obj if instantaneo else lerpf(_cam.fov, fov_obj, 1.0 - exp(-3.0 * delta))

func _leer_direccion() -> Vector2:
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		d.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		d.y -= 1.0
	return d.normalized()

func _actualizar_efectos_temporales(delta: float) -> void:
	# Temporizador de invulnerabilidad
	if inmune:
		tiempo_inmune -= delta
		modelo.visible = int(Time.get_ticks_msec() / 80) % 2 == 0
		if tiempo_inmune <= 0.0:
			inmune = false
			modelo.visible = true

	# Temporizador de escudo (8 s máximo según RF-10)
	if escudo_activo:
		tiempo_escudo -= delta
		var pulso := 2.5 + sin(Time.get_ticks_msec() * 0.008) * 1.0
		_malla_escudo.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.05)
		if tiempo_escudo <= 0.0:
			desactivar_escudo()

	# Temporizador de ralentización
	if _ralentizado_tiempo > 0.0:
		_ralentizado_tiempo -= delta
		if _ralentizado_tiempo <= 0.0:
			_ralentizado_factor = 1.0

	# Temporizador de giro por aceite
	if _giro_aceite_tiempo > 0.0:
		_giro_aceite_tiempo -= delta
		_giro_aceite_acum += delta * TAU * 2.5
		if _giro_aceite_tiempo <= 0.0:
			modelo.rotation.y = 0.0

# ---------------------------------------------------------------
# SISTEMA DE COMODINES (RF-09 a RF-13)
# ---------------------------------------------------------------
func recibir_comodin(tipo: int) -> bool:
	if comodin_almacenado != PowerUpTypes.Type.NONE:
		return false # Solo se puede almacenar 1 comodín a la vez (RF-09)
	comodin_almacenado = tipo
	if tipo == PowerUpTypes.Type.CANON:
		cargas_canon = 3
	emit_signal("comodin_cambiado", comodin_almacenado, cargas_canon)
	return true

func usar_comodin() -> void:
	if comodin_almacenado == PowerUpTypes.Type.NONE:
		return

	match comodin_almacenado:
		PowerUpTypes.Type.ESCUDO:
			activar_escudo()
			comodin_almacenado = PowerUpTypes.Type.NONE
			emit_signal("comodin_cambiado", comodin_almacenado, 0)

		PowerUpTypes.Type.CANON:
			_disparar_canon_laser()
			cargas_canon -= 1
			if cargas_canon <= 0:
				comodin_almacenado = PowerUpTypes.Type.NONE
			emit_signal("comodin_cambiado", comodin_almacenado, cargas_canon)

		PowerUpTypes.Type.BOMBA:
			_activar_bomba_area()
			comodin_almacenado = PowerUpTypes.Type.NONE
			emit_signal("comodin_cambiado", comodin_almacenado, 0)

		PowerUpTypes.Type.ACEITE:
			_colocar_trampa_aceite()
			comodin_almacenado = PowerUpTypes.Type.NONE
			emit_signal("comodin_cambiado", comodin_almacenado, 0)

func activar_escudo() -> void:
	escudo_activo = true
	tiempo_escudo = 8.0
	_malla_escudo.visible = true

func desactivar_escudo() -> void:
	escudo_activo = false
	tiempo_escudo = 0.0
	_malla_escudo.visible = false

func _disparar_laser_normal() -> void:
	var padre := get_parent()
	if padre == null: return
	var dir_tiro := -global_transform.basis.z
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var laser := Node3D.new()
		laser.set_script(load("res://laser.gd"))
		laser.set("tirador", self)
		laser.set("es_del_jugador", true)
		laser.set("es_comodin_canon", false)
		padre.add_child(laser)
		laser.global_position = to_global(Vector3(lado * 0.6, 0.0, -2.6))
		laser.global_transform = Transform3D(Basis.looking_at(dir_tiro.normalized()), laser.global_position)
		_flash(to_global(Vector3(lado * 0.6, 0.0, -2.7)), Color(1.0, 0.6, 0.2))

func _disparar_canon_laser() -> void:
	var padre := get_parent()
	if padre == null: return
	var dir_tiro := -global_transform.basis.z
	# Disparo potente central doble reforzado
	for i in 2:
		var lado: float = 0.5 if i == 1 else -0.5
		var laser := Node3D.new()
		laser.set_script(load("res://laser.gd"))
		laser.set("tirador", self)
		laser.set("es_del_jugador", true)
		laser.set("es_comodin_canon", true)
		padre.add_child(laser)
		laser.global_position = to_global(Vector3(lado, 0.0, -2.8))
		laser.global_transform = Transform3D(Basis.looking_at(dir_tiro.normalized()), laser.global_position)
		_flash(to_global(Vector3(lado, 0.0, -3.0)), Color(1.0, 0.2, 0.1))

func _activar_bomba_area() -> void:
	var padre := get_parent()
	if padre == null: return
	var bomba := OndaBomba.new()
	bomba.creador = self
	bomba.es_jugador = true
	padre.add_child(bomba)
	bomba.global_position = global_position

func _colocar_trampa_aceite() -> void:
	var padre := get_parent()
	if padre == null: return
	var trampa := TrampaAceite.new()
	trampa.creador = self
	padre.add_child(trampa)
	trampa.global_position = global_position - global_transform.basis.z * -3.5 + Vector3(0, -altura_circuito + 0.1, 0)

# ---------------------------------------------------------------
# SISTEMA DE SALUD, DAÑO Y REACCIONES DE COMBATE (RF-14)
# ---------------------------------------------------------------
func recibir_dano(cantidad: int, _origen: Vector3 = Vector3.ZERO) -> void:
	if inmune or vidas <= 0:
		return

	# Si el escudo está activo, absorbe 100% del daño del primer impacto (RF-10)
	if escudo_activo:
		desactivar_escudo()
		_efecto_absorcion_escudo()
		return

	vidas = max(0, vidas - cantidad)
	emit_signal("vidas_cambiadas", vidas, max_vidas)

	if vidas <= 0:
		_destruir_nave()
	else:
		inmune = true
		tiempo_inmune = tiempo_invulnerabilidad

func recibir_impacto_laser(es_canon: bool, _es_del_jugador: bool) -> void:
	if escudo_activo:
		desactivar_escudo()
		_efecto_absorcion_escudo()
		return
	if es_canon:
		aplicar_ralentizacion(0.40, 2.0)
	else:
		aplicar_ralentizacion(0.20, 1.0)

func recibir_impacto_bomba(direccion: Vector3) -> void:
	if escudo_activo:
		desactivar_escudo()
		_efecto_absorcion_escudo()
		return
	_empuje_lateral += direccion.x * 12.0
	aplicar_ralentizacion(0.50, 1.5)

func aplicar_ralentizacion(reduccion: float, duracion: float) -> void:
	_ralentizado_factor = 1.0 - reduccion
	_ralentizado_tiempo = duracion

func aplicar_giro_aceite(duracion: float, reduccion: float) -> void:
	if escudo_activo:
		desactivar_escudo()
		_efecto_absorcion_escudo()
		return
	_giro_aceite_tiempo = duracion
	_giro_aceite_acum = 0.0
	aplicar_ralentizacion(reduccion, duracion)

func _destruir_nave() -> void:
	control_habilitado = false
	modelo.visible = false
	emit_signal("nave_destruida")
	
	# Destello de explosión
	var destello := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	destello.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.3, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.1)
	mat.emission_energy_multiplier = 6.0
	destello.material_override = mat
	get_parent().add_child(destello)
	destello.global_position = global_position
	
	var tw := destello.create_tween()
	tw.tween_property(destello, "scale", Vector3.ONE * 3.0, 0.3)
	tw.chain().tween_callback(destello.queue_free)

func _efecto_absorcion_escudo() -> void:
	var onda := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.6
	sm.height = 7.2
	onda.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.95, 1.0)
	mat.emission_energy_multiplier = 5.0
	onda.material_override = mat
	add_child(onda)
	
	var tw := onda.create_tween()
	tw.set_parallel(true)
	tw.tween_property(onda, "scale", Vector3.ONE * 1.5, 0.25)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.chain().tween_callback(onda.queue_free)

# ---------------------------------------------------------------
# CONSTRUCCIÓN PROCEDURAL DE LA NAVE Y ESCUDO (Sección 19 y 20)
# ---------------------------------------------------------------
func _construir_escudo() -> void:
	_malla_escudo = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.5
	sm.height = 7.0
	_malla_escudo.mesh = sm
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.32)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.metallic = 0.5
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.85, 1.0)
	mat.emission_energy_multiplier = 3.2
	_malla_escudo.material_override = mat
	_malla_escudo.visible = false
	add_child(_malla_escudo)

func _flash(pos: Vector3, color: Color) -> void:
	var chispa := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	chispa.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 5.0
	chispa.material_override = m
	var padre := get_parent()
	if padre != null:
		padre.add_child(chispa)
		chispa.global_position = pos
		var tw := chispa.create_tween()
		tw.tween_property(chispa, "scale", Vector3.ONE * 2.2, 0.09)
		tw.tween_callback(chispa.queue_free)

func _crear_colision() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.6, 1.2, 5.6)
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3(0.0, 0.0, -0.8)
	add_child(col)

func _mat(color: Color, metal: float = 0.3, rugosidad: float = 0.5) -> StandardMaterial3D:
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
	c.radial_segments = 24
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
	var blanco := _mat(Color(0.86, 0.86, 0.90), 0.35, 0.45)
	var rojo := _mat(Color(0.82, 0.08, 0.12), 0.2, 0.5)
	var oscuro := _mat(Color(0.14, 0.15, 0.18), 0.6, 0.4)

	var cristal := StandardMaterial3D.new()
	cristal.albedo_color = Color(0.10, 0.45, 0.95, 0.55)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.metallic = 0.5
	cristal.roughness = 0.1
	cristal.emission_enabled = true
	cristal.emission = Color(0.10, 0.40, 1.0)
	cristal.emission_energy_multiplier = 0.4

	var luz_azul := StandardMaterial3D.new()
	luz_azul.albedo_color = Color(0.3, 0.7, 1.0)
	luz_azul.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luz_azul.emission_enabled = true
	luz_azul.emission = Color(0.2, 0.55, 1.0)
	luz_azul.emission_energy_multiplier = 3.0

	var fuego := StandardMaterial3D.new()
	fuego.albedo_color = Color(0.35, 0.75, 1.0, 0.65)
	fuego.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.emission_enabled = true
	fuego.emission = Color(0.25, 0.6, 1.0)
	fuego.emission_energy_multiplier = 2.0

	# 1. Cuerpo principal
	_pieza(_caja(Vector3(1.4, 0.5, 4.0)), blanco, Vector3(0.0, 0.0, 0.0))
	var punta := PrismMesh.new()
	punta.size = Vector3(1.4, 1.8, 0.5)
	_pieza(punta, blanco, Vector3(0.0, 0.0, -2.9), Vector3(-90.0, 0.0, 0.0))
	_pieza(_caja(Vector3(0.35, 0.03, 0.7)), rojo, Vector3(0.0, 0.26, -2.4))
	_pieza(_caja(Vector3(0.6, 0.1, 2.0)), oscuro, Vector3(0.0, -0.27, 0.3))
	_pieza(_caja(Vector3(0.9, 0.3, 1.2)), blanco, Vector3(0.0, 0.35, 0.9))

	# 2. Cabina
	_pieza(_caja(Vector3(0.8, 0.35, 1.5)), cristal, Vector3(0.0, 0.35, -0.7))
	_pieza(_caja(Vector3(0.5, 0.12, 0.25)), rojo, Vector3(0.0, 0.28, -1.6))

	# 3. Alas y aletas
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var giro := -lado * 25.0
		var base := Basis(Vector3.UP, deg_to_rad(giro))
		var centro := Vector3(lado * 2.0, -0.1, 0.9)
		_pieza(_caja(Vector3(2.8, 0.08, 1.4)), blanco, centro, Vector3(0.0, giro, 0.0))
		_pieza(_caja(Vector3(2.0, 0.02, 0.15)), rojo, centro + base * Vector3(lado * 0.1, 0.045, 0.0), Vector3(0.0, giro, 0.0))
		_pieza(_caja(Vector3(0.15, 0.1, 1.2)), rojo, centro + base * Vector3(lado * 1.4, 0.0, 0.0), Vector3(0.0, giro, 0.0))

		var aleta := _pieza(_caja(Vector3(0.08, 1.1, 0.9)), blanco, Vector3(lado * 1.15, 0.75, 1.3), Vector3(20.0, 0.0, -lado * 12.0))
		_pieza(_caja(Vector3(0.1, 0.25, 0.9)), rojo, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, aleta)

	# 4. Motores
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var x := lado * 1.0
		_pieza(_cilindro(0.36, 0.36, 2.0), blanco, Vector3(x, 0.0, 1.0), Vector3(90.0, 0.0, 0.0))
		_pieza(_cilindro(0.30, 0.30, 0.1), oscuro, Vector3(x, 0.0, -0.02), Vector3(90.0, 0.0, 0.0))
		var aro := TorusMesh.new()
		aro.inner_radius = 0.2
		aro.outer_radius = 0.38
		_pieza(aro, oscuro, Vector3(x, 0.0, 2.0), Vector3(90.0, 0.0, 0.0))
		_pieza(_cilindro(0.22, 0.22, 0.06), luz_azul, Vector3(x, 0.0, 2.0), Vector3(90.0, 0.0, 0.0))

		var pivote := Node3D.new()
		pivote.position = Vector3(x, 0.0, 2.03)
		modelo.add_child(pivote)
		_pieza(_cilindro(0.0, 0.2, 0.9), fuego, Vector3(0.0, 0.0, 0.45), Vector3(90.0, 0.0, 0.0), pivote)
		var foco := OmniLight3D.new()
		foco.light_color = Color(0.3, 0.6, 1.0)
		foco.light_energy = 1.2
		foco.omni_range = 4.0
		foco.position = Vector3(0.0, 0.0, 0.5)
		pivote.add_child(foco)
		llamas.append(pivote)

	# 5. Detalles
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		_pieza(_caja(Vector3(0.3, 0.08, 0.5)), oscuro, Vector3(lado * 0.35, 0.27, 1.6))
		_pieza(_caja(Vector3(0.05, 0.15, 0.6)), oscuro, Vector3(lado * 0.71, 0.0, -0.8))
		_pieza(_cilindro(0.04, 0.04, 0.5), oscuro, Vector3(lado * 0.3, 0.0, -2.4), Vector3(90.0, 0.0, 0.0))
	_pieza(_cilindro(0.03, 0.03, 0.4), oscuro, Vector3(0.0, 0.6, 1.3))
