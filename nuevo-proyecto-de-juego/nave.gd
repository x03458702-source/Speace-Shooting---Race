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
@export var velocidad: float = 12.0      # qué tan rápido se mueve la nave
@export var suavidad: float = 8.0        # más alto = frena y arranca más brusco
@export var limite_x: float = 7.0        # hasta dónde llega a los lados
@export var limite_y: float = 4.0        # hasta dónde llega arriba y abajo
@export var inclinacion: float = 0.5     # cuánto se ladea al moverse

@export_group("Disparo")
@export var cadencia: float = 0.15       # segundos entre disparo y disparo

@export_group("Para probar rápido")
@export var crear_camara: bool = true    # desactívalo si ya tienes tu cámara
@export var crear_luz: bool = true       # desactívalo si ya tienes tu luz

# ---------------------------------------------------------------
# VARIABLES INTERNAS
# ---------------------------------------------------------------
var modelo: Node3D                        # aquí cuelgan todas las piezas visibles
var llamas: Array[Node3D] = []            # las llamas de los motores
var _tiempo_disparo: float = 0.0


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
	# Salen dos lásers, uno por cada lado de la punta de la nave.
	# Necesitas el archivo laser.gd en la misma carpeta que este script.
	var padre := get_parent()
	for i in 2:
		var lado: float = 1.0 if i == 1 else -1.0
		var laser := Node3D.new()
		laser.set_script(load("res://laser.gd"))
		padre.add_child(laser)
		laser.global_position = to_global(Vector3(lado * 0.6, 0.0, -2.6))


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
