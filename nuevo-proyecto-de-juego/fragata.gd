extends CharacterBody3D
## FRAGATA EXPLORADORA 3D (Godot 4)
## Este script ARMA la nave completa con piezas (esferas aplastadas, cilindros,
## toros y cajas), le pone colores y materiales, la mueve con el teclado
## y dispara lásers.
##
## USO: ponle este script a un nodo CharacterBody3D vacío (sin hijos).
## Movimiento: WASD o flechas | Disparo: barra espaciadora o clic izquierdo
## Necesita el archivo laser.gd en la misma carpeta (res://).

# ---------------------------------------------------------------
# AJUSTES (los puedes cambiar desde el Inspector sin tocar el código)
# ---------------------------------------------------------------
@export_group("Movimiento")
@export var velocidad: float = 10.0      # qué tan rápido se mueve la nave
@export var suavidad: float = 8.0        # más alto = frena y arranca más brusco
@export var limite_x: float = 7.0        # hasta dónde llega a los lados
@export var limite_y: float = 4.0        # hasta dónde llega arriba y abajo
@export var inclinacion: float = 0.4     # cuánto se ladea al moverse

@export_group("Tamaño")
@export var escala: float = 0.65         # 1.0 = tamaño grande, 0.5 = más pequeña

@export_group("Disparo")
@export var cadencia: float = 0.2        # segundos entre disparo y disparo

@export_group("Para probar rápido")
@export var crear_camara: bool = true    # desactívalo si ya tienes tu cámara
@export var crear_luz: bool = true       # desactívalo si ya tienes tu luz

# ---------------------------------------------------------------
# VARIABLES INTERNAS
# ---------------------------------------------------------------
var modelo: Node3D                        # aquí cuelgan todas las piezas visibles
var llamas: Array[Node3D] = []            # las llamas de los motores
var _tiempo_disparo: float = 0.0

# Materiales (los colores de la imagen)
var titanio: StandardMaterial3D           # blanco titanio (casco)
var oscuro: StandardMaterial3D            # gris oscuro (zonas internas)
var violeta: StandardMaterial3D           # violeta neón (detalles)
var jade: StandardMaterial3D              # verde jade (motores)
var azul_luz: StandardMaterial3D          # azul (luces)
var cristal: StandardMaterial3D           # azul transparente (cabina)
var fuego: StandardMaterial3D             # llama de los motores


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING  # sin gravedad, es el espacio
	add_to_group("jugador")

	modelo = Node3D.new()
	modelo.name = "Modelo"
	modelo.scale = Vector3.ONE * escala
	add_child(modelo)

	_construir_nave()
	_crear_colision()

	if crear_luz:
		var luz := DirectionalLight3D.new()
		luz.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
		luz.light_energy = 1.3
		add_child(luz)

	if crear_camara:
		var camara := Camera3D.new()
		camara.top_level = true                       # la cámara NO sigue a la nave
		add_child(camara)
		camara.global_position = Vector3(0.0, 2.0, 11.0)
		camara.rotation_degrees = Vector3(-6.0, 0.0, 0.0)
		camara.current = true


func _physics_process(delta: float) -> void:
	var dir := _leer_direccion()

	# --- Movimiento suave ---
	var objetivo := Vector3(dir.x, dir.y, 0.0) * velocidad
	velocity = velocity.lerp(objetivo, 1.0 - exp(-suavidad * delta))
	move_and_slide()
	position.x = clampf(position.x, -limite_x, limite_x)
	position.y = clampf(position.y, -limite_y, limite_y)

	# --- La nave se ladea un poquito al moverse ---
	var t := 1.0 - exp(-6.0 * delta)
	modelo.rotation.z = lerpf(modelo.rotation.z, -dir.x * inclinacion, t)
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
	# Salen dos lásers, uno de cada cañón (los cañones están bajo el casco).
	var padre := get_parent()
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var laser := Node3D.new()
		laser.set_script(load("res://laser.gd"))
		padre.add_child(laser)
		laser.global_position = to_global(Vector3(lado * 0.75, -0.3, -2.7) * escala)


# ---------------------------------------------------------------
# HITBOX (la zona que "recibe" los golpes)
# ---------------------------------------------------------------
func _crear_colision() -> void:
	var forma := BoxShape3D.new()
	forma.size = Vector3(2.0, 0.9, 9.0) * escala
	var col := CollisionShape3D.new()
	col.shape = forma
	col.position = Vector3(0.0, 0.0, -0.8) * escala
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


func _emisivo(color: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
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


func _esfera() -> SphereMesh:
	# Esfera de radio 1. Al "aplastarla" con la escala se vuelve una pieza orgánica.
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 32
	s.rings = 16
	return s


func _pieza(malla: Mesh, mat: Material, pos: Vector3, rot_grados: Vector3 = Vector3.ZERO, tam: Vector3 = Vector3.ONE, padre: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_grados
	mi.scale = tam
	if padre == null:
		padre = modelo
	padre.add_child(mi)
	return mi


func _crear_materiales() -> void:
	titanio = _mat(Color(0.82, 0.83, 0.90), 0.75, 0.28)
	oscuro = _mat(Color(0.16, 0.17, 0.20), 0.6, 0.4)
	violeta = _emisivo(Color(0.72, 0.35, 1.0), 2.5)
	jade = _emisivo(Color(0.20, 0.90, 0.60), 2.5)
	azul_luz = _emisivo(Color(0.30, 0.65, 1.0), 3.0)
	azul_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	cristal = StandardMaterial3D.new()
	cristal.albedo_color = Color(0.10, 0.45, 0.95, 0.5)
	cristal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cristal.metallic = 0.5
	cristal.roughness = 0.1
	cristal.emission_enabled = true
	cristal.emission = Color(0.10, 0.40, 1.0)
	cristal.emission_energy_multiplier = 0.4

	fuego = StandardMaterial3D.new()
	fuego.albedo_color = Color(0.75, 0.40, 1.0, 0.65)
	fuego.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fuego.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fuego.emission_enabled = true
	fuego.emission = Color(0.65, 0.30, 1.0)
	fuego.emission_energy_multiplier = 2.0


# ---------------------------------------------------------------
# CONSTRUCCIÓN DE LA NAVE (sigue los componentes de la imagen)
# La nave apunta hacia -Z (hacia el fondo de la pantalla).
# ---------------------------------------------------------------
func _construir_nave() -> void:
	_crear_materiales()
	var esfera := _esfera()

	# ---------- 1. MÓDULO DEL CASCO ----------
	# Casco largo y liso (una esfera estirada)
	_pieza(esfera, titanio, Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 3.6))
	# Vientre oscuro
	_pieza(esfera, oscuro, Vector3(0.0, -0.3, 0.2), Vector3.ZERO, Vector3(0.75, 0.25, 3.0))
	# Nariz larga y afilada (un cono acostado, aplastado por arriba y abajo)
	_pieza(_cilindro(0.0, 0.46, 2.2), titanio, Vector3(0.0, 0.0, -4.3), Vector3(-90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.55))
	# Luz azul en la punta de la nariz
	_pieza(esfera, azul_luz, Vector3(0.0, 0.0, -5.35), Vector3.ZERO, Vector3(0.07, 0.07, 0.07))

	# Líneas de luz verde jade a los lados del casco
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		_pieza(_caja(Vector3(0.04, 0.05, 1.6)), jade, Vector3(lado * 0.96, 0.02, 0.3))

	# ---------- 2. CABINA PANORÁMICA (cristal) ----------
	_pieza(esfera, oscuro, Vector3(0.0, 0.42, -1.5), Vector3.ZERO, Vector3(0.6, 0.08, 1.45))   # marco
	_pieza(esfera, cristal, Vector3(0.0, 0.28, -1.5), Vector3.ZERO, Vector3(0.55, 0.33, 1.4))  # vidrio

	# ---------- 4. ALAS (elipses delgadas) Y ALETAS DE ESTABILIZACIÓN ----------
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var giro := -lado * 28.0                                   # las alas van hacia atrás
		var base := Basis(Vector3.UP, deg_to_rad(giro))
		var centro := Vector3(lado * 2.3, -0.05, 0.9)
		_pieza(esfera, titanio, centro, Vector3(0.0, giro, 0.0), Vector3(1.7, 0.06, 0.8))
		# Franja violeta sobre el ala
		_pieza(_caja(Vector3(2.0, 0.02, 0.06)), violeta, centro + base * Vector3(0.0, 0.05, 0.0), Vector3(0.0, giro, 0.0))

		# Aleta de estabilización en la punta del ala
		var punta := centro + base * Vector3(lado * 1.6, 0.0, 0.0)
		var aleta := _pieza(_caja(Vector3(0.06, 0.8, 0.7)), titanio, punta + Vector3(0.0, 0.3, 0.0), Vector3(15.0, 0.0, -lado * 15.0))
		_pieza(_caja(Vector3(0.08, 0.12, 0.7)), violeta, Vector3(0.0, 0.4, 0.0), Vector3.ZERO, Vector3.ONE, aleta)
		# Luz azul de navegación
		_pieza(esfera, azul_luz, punta, Vector3.ZERO, Vector3(0.07, 0.07, 0.07))

	# Aleta central de la cola
	var cola := _pieza(_caja(Vector3(0.07, 0.9, 1.0)), titanio, Vector3(0.0, 0.75, 2.3), Vector3(25.0, 0.0, 0.0))
	_pieza(_caja(Vector3(0.09, 0.06, 1.0)), violeta, Vector3(0.0, 0.45, 0.0), Vector3.ZERO, Vector3.ONE, cola)

	# ---------- 3. PROPULSORES (uno principal y dos laterales) ----------
	_crear_motor(Vector3(0.0, 0.0, 3.1), 0.5, 1.4, 1.0)
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		_crear_motor(Vector3(lado * 1.05, -0.05, 2.6), 0.32, 1.8, 0.6)

	# ---------- 7. DETALLES ADICIONALES ----------
	# Array de sensores: un mástil con un plato que mira hacia adelante
	_pieza(_cilindro(0.03, 0.03, 0.5), oscuro, Vector3(0.0, 0.7, 1.6))
	_pieza(_cilindro(0.5, 0.05, 0.15), titanio, Vector3(0.0, 0.98, 1.55), Vector3(-35.0, 0.0, 0.0))
	_pieza(_caja(Vector3(0.1, 0.1, 0.1)), jade, Vector3(0.0, 1.05, 1.4))

	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		# Módulo oscuro a cada lado del casco, con lucecita verde
		_pieza(_caja(Vector3(0.3, 0.14, 0.7)), oscuro, Vector3(lado * 0.88, -0.18, -0.6))
		_pieza(_caja(Vector3(0.05, 0.05, 0.3)), jade, Vector3(lado * 1.04, -0.18, -0.6))
		# Cañones bajo el casco
		_pieza(_cilindro(0.05, 0.05, 1.6), oscuro, Vector3(lado * 0.75, -0.3, -1.8), Vector3(90.0, 0.0, 0.0))


# Crea un propulsor completo: cuerpo, bandas de luz, aro, brillo y llama.
func _crear_motor(centro: Vector3, radio: float, largo: float, tam_llama: float) -> void:
	var acostado := Vector3(90.0, 0.0, 0.0)          # el cilindro queda a lo largo de Z
	var atras := centro.z + largo * 0.5

	# Cuerpo del motor
	_pieza(_cilindro(radio, radio, largo), titanio, centro, acostado)
	# Dos bandas de luz verde jade
	for k in 2:
		var dz := (-0.25 + 0.5 * k) * largo
		_pieza(_cilindro(radio + 0.02, radio + 0.02, largo * 0.12), jade, Vector3(centro.x, centro.y, centro.z + dz), acostado)
	# Entrada de aire oscura al frente
	_pieza(_cilindro(radio * 0.85, radio * 0.85, 0.12), oscuro, Vector3(centro.x, centro.y, centro.z - largo * 0.5), acostado)

	# Aro oscuro atrás (TorusMesh)
	var aro := TorusMesh.new()
	aro.inner_radius = radio * 0.55
	aro.outer_radius = radio * 1.05
	_pieza(aro, oscuro, Vector3(centro.x, centro.y, atras), acostado)
	# Disco violeta brillante dentro del aro
	_pieza(_cilindro(radio * 0.6, radio * 0.6, 0.06), violeta, Vector3(centro.x, centro.y, atras), acostado)

	# Llama (un cono violeta que apunta hacia atrás) y su luz
	var pivote := Node3D.new()
	pivote.position = Vector3(centro.x, centro.y, atras + 0.03)
	modelo.add_child(pivote)
	var largo_llama := 1.1 * tam_llama
	_pieza(_cilindro(0.0, radio * 0.6, largo_llama), fuego, Vector3(0.0, 0.0, largo_llama * 0.5), acostado, Vector3.ONE, pivote)
	var foco := OmniLight3D.new()
	foco.light_color = Color(0.7, 0.4, 1.0)
	foco.light_energy = 1.2 * tam_llama
	foco.omni_range = 4.0
	foco.position = Vector3(0.0, 0.0, largo_llama * 0.5)
	pivote.add_child(foco)
	llamas.append(pivote)
