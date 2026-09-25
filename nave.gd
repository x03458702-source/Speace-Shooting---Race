extends CharacterBody3D
## NAVE ESPACIAL 3D (Godot 4)
## Este script ARMA la nave completa con piezas (cajas, cilindros, toros),
## le pone colores y materiales, la mueve con el teclado y dispara lásers.
##
## USO: ponle este script a un nodo CharacterBody3D vacío (sin hijos).
## Movimiento: WASD o flechas | Disparo: barra espaciadora o clic izquierdo

# ---------------------------------------------------------------
# AJUSTES (los puedes cambiar desde el Inspector sin tocar el código)
# ---------------------------------------------------------------
@export_group("Movimiento")
@export var velocidad: float = 5.0       # movimientos A/D/W/S lentos y pesados
@export var suavidad: float = 8.0        # más alto = frena y arranca más brusco
@export var limite_x: float = 7.0        # hasta dónde llega a los lados
@export var limite_y: float = 4.0        # hasta dónde llega arriba y abajo
@export var inclinacion: float = 0.5     # cuánto se ladea al moverse

@export_group("Carrera")
@export var auto_avanzar: bool = true    # si avanza sola hacia -Z (modo carrera)
@export var avance: float = 28.0         # velocidad de avance en pista
@export var limite_z_min: float = -960.0 # meta: al llegar, da la vuelta (bucle sin fin)
@export var limite_z_max: float = 960.0
@export var vueltas: int = 0             # contador de vueltas completadas

@export_group("Circuito en V")
@export var modo_circuito: bool = false  # true = sigue el trazado en vez de ir recto
@export var altura_circuito: float = 2.6 # altura de vuelo sobre la pista
@export var medio_ancho: float = 20.0    # apertura lateral máxima (el circuito la limita)

@export_group("Disparo")
@export var cadencia: float = 0.18       # zaps separados: se leen rectos, no en manguera

@export_group("Para probar rápido")
@export var crear_camara: bool = true    # desactívalo si ya tienes tu cámara
@export var crear_luz: bool = true       # desactívalo si ya tienes tu luz

# ---------------------------------------------------------------
# VARIABLES INTERNAS
# ---------------------------------------------------------------
var modelo: Node3D                        # aquí cuelgan todas las piezas visibles
var llamas: Array[Node3D] = []            # las llamas de los motores
var _tiempo_disparo: float = 0.0
var _lat: float = 0.0                     # desplazamiento lateral sobre la pista
var _alt: float = 0.0                     # altura extra (W/S, suavizada)
var _bank_extra: float = 0.0              # ladeo extra en curvas (modo circuito)
var _cam: Camera3D                        # cámara perseguidora (modo circuito)
var _cam_yaw: float = 0.0                 # giro propio de la cámara (con retardo)
var _pp := PackedVector3Array()           # línea central del circuito
var _pw := PackedFloat32Array()           # ancho en cada punto
var _pc := PackedFloat32Array()           # distancias acumuladas
var _ptotal := 0.0                        # longitud de la vuelta
var _s := 0.0                             # avance sobre el trazado


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING  # sin gravedad, es el espacio
	add_to_group("jugador")

	modelo = Node3D.new()
	modelo.name = "Modelo"
	add_child(modelo)

	_construir_nave()
	_crear_colision()

	if crear_luz:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		luz.light_energy = 1.3
		add_child(luz)

	if crear_camara:
		if modo_circuito:
			# Cámara libre con retardo (no va soldada: se queda atrás en las curvas)
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


## El circuito le pasa su trazado (puntos + anchos). Una sola fuente de verdad.
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


## Punto de la línea central a distancia s: [pos, tangente, ancho].
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


## Coloca la nave sobre el trazado (sin física, cinemático).
func _snap_circuito() -> void:
	var m := _punto_en(_s)
	var centro: Vector3 = m[0]
	var t: Vector3 = m[1]
	global_position = centro + Vector3(0.0, altura_circuito, 0.0)
	rotation.y = atan2(-t.x, -t.z)
	rotation.x = 0.0
	velocity = t * avance


## Avance sobre el trazado en V: A/D te abren a los lados, W/S suben/bajan.
## En las V angostas el lateral se limita solo al ancho de la curva.
func _proceso_circuito(delta: float, dir: Vector2) -> void:
	var adelante := _punto_en(_s + 40.0)[1] as Vector3
	var m := _punto_en(_s)
	var centro: Vector3 = m[0]
	var t: Vector3 = m[1]
	var w := float(m[2])
	var giro := t.angle_to(adelante) / PI
	var v := avance * (1.0 - 0.25 * clampf(giro * 2.0, 0.0, 1.0)) if auto_avanzar else 0.0
	_s += v * delta
	if _s >= _ptotal and _ptotal > 0.0:
		_s -= _ptotal
		vueltas += 1
		print("¡Vuelta ", vueltas, " completada!")
	m = _punto_en(_s)
	centro = m[0]
	t = m[1]
	w = float(m[2])
	var right := Vector3(-t.z, 0.0, t.x)
	var mitad := minf(medio_ancho, maxf(w * 0.5 - 2.0, 4.0))
	_lat = lerpf(_lat, dir.x * medio_ancho, 1.0 - exp(-1.6 * delta))
	_lat = clampf(_lat, -mitad, mitad)
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


## Cámara perseguidora: gira con retardo tras la nave y abre el FOV con la velocidad.
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


func _physics_process(delta: float) -> void:
	var dir := _leer_direccion()

	if modo_circuito:
		_proceso_circuito(delta, dir)
	else:
		_movimiento_recto(delta, dir)

	# --- La nave se ladea un poquito al moverse (más el banqueo en curvas) ---
	var t := 1.0 - exp(-6.0 * delta)
	modelo.rotation.z = lerpf(modelo.rotation.z, -dir.x * inclinacion + _bank_extra, t)
	modelo.rotation.x = lerpf(modelo.rotation.x, dir.y * inclinacion * 0.5, t)

	# --- Llamas de los motores (parpadean y crecen con la velocidad) ---
	var fuerza := 1.0 + velocity.length() * 0.03
	for llama in llamas:
		llama.scale.z = fuerza * randf_range(0.8, 1.2)

	# --- Disparo ---
	_tiempo_disparo -= delta
	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _tiempo_disparo <= 0.0:
			_disparar()
			_tiempo_disparo = cadencia


## Avance recto de la pista infinita (modo no-circuito).
func _movimiento_recto(delta: float, dir: Vector2) -> void:
	_bank_extra = 0.0
	var vz := -avance if auto_avanzar else 0.0
	var objetivo := Vector3(dir.x * velocidad, dir.y * velocidad, vz)
	velocity = velocity.lerp(objetivo, 1.0 - exp(-suavidad * delta))
	move_and_slide()
	position.x = clampf(position.x, -limite_x, limite_x)
	position.y = clampf(position.y, -limite_y, limite_y)
	# --- Bucle sin fin: al cruzar la meta vuelve al inicio ---
	if position.z <= limite_z_min:
		position.z = limite_z_max
		vueltas += 1
		print("¡Vuelta ", vueltas, " completada!")
	else:
		position.z = clampf(position.z, limite_z_min, limite_z_max)


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


func _disparar() -> void:
	# Dos lásers PARALELOS hacia donde apunta el MORRO: salen rectos
	# de los cañones. Necesita laser.gd en la misma carpeta.
	var padre := get_parent()
	var dir_tiro := -global_transform.basis.z
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var laser := Node3D.new()
		laser.set_script(load("res://laser.gd"))
		padre.add_child(laser)
		laser.global_position = to_global(Vector3(lado * 0.6, 0.0, -2.6))
		laser.global_transform = Transform3D(Basis.looking_at(dir_tiro.normalized()), laser.global_position)
		_flash(to_global(Vector3(lado * 0.6, 0.0, -2.7)))


## Destello en la boca del cañón al disparar (crece y se apaga en 0.09 s).
func _flash(pos: Vector3) -> void:
	var chispa := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	chispa.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.6, 0.2)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.15)
	m.emission_energy_multiplier = 5.0
	chispa.material_override = m
	get_parent().add_child(chispa)
	chispa.global_position = pos
	var tw := chispa.create_tween()
	tw.tween_property(chispa, "scale", Vector3.ONE * 2.2, 0.09)
	tw.tween_callback(chispa.queue_free)


# ---------------------------------------------------------------
# HITBOX (la zona que "recibe" los golpes)
# ---------------------------------------------------------------
func _crear_colision() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.6, 0.9, 5.6)
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3(0.0, 0.0, -0.8)
	add_child(col)


# ---------------------------------------------------------------
# AYUDANTES PARA CREAR PIEZAS Y MATERIALES
# ---------------------------------------------------------------
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


# ---------------------------------------------------------------
# CONSTRUCCIÓN DE LA NAVE (sigue la lista de componentes de la imagen)
# La nave apunta hacia -Z (hacia el fondo de la pantalla).
# ---------------------------------------------------------------
func _construir_nave() -> void:
	# ---------- MATERIALES (colores de la imagen) ----------
	var blanco := _mat(Color(0.86, 0.86, 0.90), 0.35, 0.45)   # cuerpo
	var rojo := _mat(Color(0.82, 0.08, 0.12), 0.2, 0.5)       # detalles
	var oscuro := _mat(Color(0.14, 0.15, 0.18), 0.6, 0.4)     # motores y zonas internas

	var cristal := StandardMaterial3D.new()                   # cabina azul
	cristal.albedo_color = Color(0.10, 0.45, 0.95, 0.55)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.metallic = 0.5
	cristal.roughness = 0.1
	cristal.emission_enabled = true
	cristal.emission = Color(0.10, 0.40, 1.0)
	cristal.emission_energy_multiplier = 0.4

	var luz_azul := StandardMaterial3D.new()                  # luces azules brillantes
	luz_azul.albedo_color = Color(0.3, 0.7, 1.0)
	luz_azul.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	luz_azul.emission_enabled = true
	luz_azul.emission = Color(0.2, 0.55, 1.0)
	luz_azul.emission_energy_multiplier = 3.0

	var fuego := StandardMaterial3D.new()                     # llama del motor
	fuego.albedo_color = Color(0.35, 0.75, 1.0, 0.65)
	fuego.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.emission_enabled = true
	fuego.emission = Color(0.25, 0.6, 1.0)
	fuego.emission_energy_multiplier = 2.0

	# ---------- 1. CUERPO PRINCIPAL (BoxMesh + PrismMesh para la punta) ----------
	_pieza(_caja(Vector3(1.4, 0.5, 4.0)), blanco, Vector3(0.0, 0.0, 0.0))

	var punta := PrismMesh.new()                              # nariz en punta
	punta.size = Vector3(1.4, 1.8, 0.5)
	_pieza(punta, blanco, Vector3(0.0, 0.0, -2.9), Vector3(-90.0, 0.0, 0.0))

	_pieza(_caja(Vector3(0.35, 0.03, 0.7)), rojo, Vector3(0.0, 0.26, -2.4))       # franja roja de la nariz
	_pieza(_caja(Vector3(0.6, 0.1, 2.0)), oscuro, Vector3(0.0, -0.27, 0.3))       # panel oscuro de abajo
	_pieza(_caja(Vector3(0.9, 0.3, 1.2)), blanco, Vector3(0.0, 0.35, 0.9))        # joroba trasera

	# ---------- 2. CABINA (BoxMesh azul) ----------
	_pieza(_caja(Vector3(0.8, 0.35, 1.5)), cristal, Vector3(0.0, 0.35, -0.7))
	_pieza(_caja(Vector3(0.5, 0.12, 0.25)), rojo, Vector3(0.0, 0.28, -1.6))       # cuña roja frente a la cabina

	# ---------- 3. ALAS (BoxMesh) y 4. ALETAS (BoxMesh) ----------
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		# Ala inclinada hacia atrás
		var giro := -lado * 25.0
		var base := Basis(Vector3.UP, deg_to_rad(giro))
		var centro := Vector3(lado * 2.0, -0.1, 0.9)
		_pieza(_caja(Vector3(2.8, 0.08, 1.4)), blanco, centro, Vector3(0.0, giro, 0.0))
		# Franja roja del ala
		_pieza(_caja(Vector3(2.0, 0.02, 0.15)), rojo, centro + base * Vector3(lado * 0.1, 0.045, 0.0), Vector3(0.0, giro, 0.0))
		# Punta roja del ala
		_pieza(_caja(Vector3(0.15, 0.1, 1.2)), rojo, centro + base * Vector3(lado * 1.4, 0.0, 0.0), Vector3(0.0, giro, 0.0))

		# Aleta vertical (inclinada hacia afuera y hacia atrás)
		var aleta := _pieza(_caja(Vector3(0.08, 1.1, 0.9)), blanco, Vector3(lado * 1.15, 0.75, 1.3), Vector3(20.0, 0.0, -lado * 12.0))
		_pieza(_caja(Vector3(0.1, 0.25, 0.9)), rojo, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, aleta)  # punta roja

	# ---------- 5. MOTORES (CylinderMesh) y 6. DETALLE DE MOTOR (Cylinder + Torus) ----------
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var x := lado * 1.0
		# Cuerpo del motor (acostado: el cilindro apunta a lo largo de Z)
		_pieza(_cilindro(0.36, 0.36, 2.0), blanco, Vector3(x, 0.0, 1.0), Vector3(90.0, 0.0, 0.0))
		# Entrada de aire oscura al frente
		_pieza(_cilindro(0.30, 0.30, 0.1), oscuro, Vector3(x, 0.0, -0.02), Vector3(90.0, 0.0, 0.0))
		# Aro oscuro atrás (TorusMesh)
		var aro := TorusMesh.new()
		aro.inner_radius = 0.2
		aro.outer_radius = 0.38
		_pieza(aro, oscuro, Vector3(x, 0.0, 2.0), Vector3(90.0, 0.0, 0.0))
		# Disco azul brillante dentro del aro
		_pieza(_cilindro(0.22, 0.22, 0.06), luz_azul, Vector3(x, 0.0, 2.0), Vector3(90.0, 0.0, 0.0))

		# Llama (un cono azul que apunta hacia atrás) + luz azul
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

	# ---------- 7. DETALLES (BoxMesh / CylinderMesh) ----------
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		_pieza(_caja(Vector3(0.3, 0.08, 0.5)), oscuro, Vector3(lado * 0.35, 0.27, 1.6))    # rejillas de arriba
		_pieza(_caja(Vector3(0.05, 0.15, 0.6)), oscuro, Vector3(lado * 0.71, 0.0, -0.8))   # tomas de aire laterales
		_pieza(_cilindro(0.04, 0.04, 0.5), oscuro, Vector3(lado * 0.3, 0.0, -2.4), Vector3(90.0, 0.0, 0.0))  # cañones
	_pieza(_cilindro(0.03, 0.03, 0.4), oscuro, Vector3(0.0, 0.6, 1.3))                     # antena
