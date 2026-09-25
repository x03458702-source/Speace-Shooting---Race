extends Node3D
## CIRCUITO F1 CON HORQUILLAS EN "V" (Godot 4)
## Pista generada por código: ancha en rectas, angosta en las curvas en V.
## Trazado: dos rectas en x=±rx unidas por puntas en V en z=±(rz+punta).
##
## USO: escena con este script en la raíz + una instancia de Nave.tscn llamada "Nave".

@export_group("Circuito")
@export var rx: float = 150.0          # separación de las rectas (mitad)
@export var rz: float = 700.0          # largo de las rectas (mitad)
@export var punta: float = 150.0       # cuánto sobresale la V
@export var ancho_recta: float = 44.0  # ancha en rectas
@export var ancho_curva: float = 22.0  # angosta en las V
@export var num_puertas: int = 8       # puntos de control
@export var avance_nave: float = 28.0
@export var altura_nave: float = 2.6

var _pts := PackedVector3Array()
var _anchos := PackedFloat32Array()
var _acum := PackedFloat32Array()
var _total := 0.0

var _asfalto: StandardMaterial3D
var _cian: StandardMaterial3D
var _blanco: StandardMaterial3D
var _puerta: StandardMaterial3D
var _meta: StandardMaterial3D
var _roca: StandardMaterial3D
var _roca2: StandardMaterial3D
var _metal: StandardMaterial3D
var _rivales: Array[Node] = []
var _race_manager: SistemaCarrera
var _hud: HUDJuego


func _ready() -> void:
	_crear_materiales()
	_trazar()
	_construir_entorno()
	_construir_suelo()
	_construir_pista()
	_construir_puertas()
	_construir_decorado()
	_construir_cajas_comodines()
	_construir_obstaculos()
	_construir_rivales_ia()
	_configurar_nave()
	_configurar_sistemas_carrera()


func _configurar_nave() -> void:
	var nave := get_node_or_null("Nave")
	if nave != null and nave.has_method("cargar_circuito"):
		nave.cargar_circuito(_pts, _anchos)
		if nave.has_method("set"):
			nave.set("_lat", -6.0)
	else:
		push_warning("CircuitoOvalado: no se encontró el nodo 'Nave' con modo circuito.")


# ---------------------------------------------------------------
# COMODINES, OBSTÁCULOS E IA DE RIVALES
# ---------------------------------------------------------------
func _construir_cajas_comodines() -> void:
	var nodo_cajas := Node3D.new()
	nodo_cajas.name = "CajasComodines"
	add_child(nodo_cajas)

	# 4 estaciones de cajas a lo largo del circuito (RF-08)
	var fracciones := [0.15, 0.38, 0.62, 0.85]
	for frac in fracciones:
		var dist: float = _total * frac
		var m := _muestrear(dist)
		var centro: Vector3 = m[0]
		var t: Vector3 = m[1]
		var w := float(m[2])
		var right := Vector3(-t.z, 0.0, t.x)

		# 3 cajas en fila cruzando el ancho de la pista
		for offset in [-7.0, 0.0, 7.0]:
			if abs(offset) < w * 0.42:
				var caja := CajaComodin.new()
				nodo_cajas.add_child(caja)
				caja.global_position = centro + right * offset + Vector3(0, 0.2, 0)
				caja.rotation.y = atan2(-t.x, -t.z)


func _construir_obstaculos() -> void:
	var nodo_obs := Node3D.new()
	nodo_obs.name = "Obstaculos"
	add_child(nodo_obs)

	# 1. Asteroides destructibles en rectas y antes de curvas (Sección 22)
	var distancias_asteroides := [
		[220.0, -5.0], [420.0, 6.0], [600.0, 0.0],
		[880.0, -7.0], [1150.0, 6.0], [1380.0, -4.0],
		[1580.0, 5.0], [1850.0, -6.0], [2100.0, 4.0],
		[2300.0, -5.0]
	]

	for dato in distancias_asteroides:
		var s: float = fposmod(float(dato[0]), _total)
		var m := _muestrear(s)
		var centro: Vector3 = m[0]
		var t: Vector3 = m[1]
		var w := float(m[2])
		var right := Vector3(-t.z, 0.0, t.x)
		var lat := clampf(float(dato[1]), -w * 0.38, w * 0.38)

		var asteroide := ObstaculoAsteroide.new()
		asteroide.add_to_group("obstaculos")
		nodo_obs.add_child(asteroide)
		asteroide.global_position = centro + right * lat + Vector3(0, 2.4, 0)

	# 2. Barreras energéticas en zonas estratégicas
	var barreras_datos := [
		[_total * 0.28, 7.0, 14.0],   # Bloquea carril derecho
		[_total * 0.72, -7.0, 14.0]   # Bloquea carril izquierdo
	]

	for b_dato in barreras_datos:
		var s: float = float(b_dato[0])
		var m := _muestrear(s)
		var centro: Vector3 = m[0]
		var t: Vector3 = m[1]
		var right := Vector3(-t.z, 0.0, t.x)

		var barrera := BarreraEnergetica.new()
		barrera.ancho = float(b_dato[2])
		barrera.add_to_group("obstaculos")
		nodo_obs.add_child(barrera)
		barrera.global_position = centro + right * float(b_dato[1])
		barrera.rotation.y = atan2(-t.x, -t.z)


func _construir_rivales_ia() -> void:
	_rivales.clear()
	var nodo_rivales := Node3D.new()
	nodo_rivales.name = "RivalesIA"
	add_child(nodo_rivales)

	var configs_rivales := [
		{
			"nombre": "ARES",
			"primario": Color(0.85, 0.12, 0.15),
			"secundario": Color(0.95, 0.75, 0.1),
			"energia": Color(1.0, 0.35, 0.1),
			"vel": 28.2,
			"s_offset": -8.0,
			"lat": 6.0
		},
		{
			"nombre": "VIPER",
			"primario": Color(0.1, 0.65, 0.25),
			"secundario": Color(0.15, 0.18, 0.22),
			"energia": Color(0.2, 0.95, 0.5),
			"vel": 27.6,
			"s_offset": -16.0,
			"lat": -6.0
		},
		{
			"nombre": "NOVA",
			"primario": Color(0.48, 0.12, 0.75),
			"secundario": Color(0.8, 0.85, 0.9),
			"energia": Color(0.75, 0.2, 1.0),
			"vel": 27.0,
			"s_offset": -24.0,
			"lat": 6.0
		}
	]

	for cfg in configs_rivales:
		var rival := NaveRivalIA.new()
		rival.name = "Rival_" + String(cfg["nombre"])
		rival.nombre_piloto = String(cfg["nombre"])
		rival.color_primario = cfg["primario"]
		rival.color_secundario = cfg["secundario"]
		rival.color_energia = cfg["energia"]
		rival.avance_base = float(cfg["vel"])
		rival.total_vueltas_carrera = 3
		nodo_rivales.add_child(rival)
		rival.cargar_circuito(_pts, _anchos, float(cfg["s_offset"]), float(cfg["lat"]))
		_rivales.append(rival)


func _configurar_sistemas_carrera() -> void:
	var nave := get_node_or_null("Nave")
	if nave == null:
		return

	_race_manager = SistemaCarrera.new()
	_race_manager.total_vueltas = 3
	add_child(_race_manager)

	_hud = HUDJuego.new()
	add_child(_hud)

	_race_manager.configurar_participantes(nave, _rivales)
	_hud.vincular(nave, _race_manager)



# ---------------------------------------------------------------
# TRAZADO (línea central + anchos + longitudes acumuladas)
# ---------------------------------------------------------------
func _trazar() -> void:
	var esquinas := [
		Vector3(rx, 0, -rz), Vector3(rx, 0, rz), Vector3(0, 0, rz + punta),
		Vector3(-rx, 0, rz), Vector3(-rx, 0, -rz), Vector3(0, 0, -rz - punta),
	]
	_pts.clear()
	_anchos.clear()
	_pts.append(esquinas[0])
	_anchos.append(ancho_recta)
	for i in 6:
		var a: Vector3 = esquinas[i]
		var b: Vector3 = esquinas[(i + 1) % 6]
		var recta := (i == 0 or i == 3)
		var paso := 25.0 if recta else 12.0
		var w := ancho_recta if recta else ancho_curva
		var n := maxi(1, ceili(a.distance_to(b) / paso))
		for k in range(1, n + 1):
			_pts.append(a.lerp(b, float(k) / float(n)))
			_anchos.append(w)
	if _pts.size() > 1 and _pts[_pts.size() - 1].distance_to(_pts[0]) < 0.01:
		_pts.remove_at(_pts.size() - 1)
		_anchos.remove_at(_anchos.size() - 1)
	_acum.clear()
	_acum.append(0.0)
	var acc := 0.0
	var n := _pts.size()
	for i in n:
		acc += _pts[i].distance_to(_pts[(i + 1) % n])
		_acum.append(acc)
	_total = acc


## Muestra [pos, tangente, ancho] a la distancia s del trazado.
func _muestrear(s: float) -> Array:
	var n := _pts.size()
	var ss := fposmod(s, _total)
	var i := 0
	while i < n - 1 and _acum[i + 1] <= ss:
		i += 1
	var a := _acum[i]
	var b := _acum[i + 1]
	var f := 0.0
	if b > a:
		f = (ss - a) / (b - a)
	var p0 := _pts[i]
	var p1 := _pts[(i + 1) % n]
	var tan := p1 - p0
	if tan.length() < 0.001:
		tan = Vector3(0, 0, 1)
	else:
		tan = tan.normalized()
	return [p0.lerp(p1, f), tan, lerpf(_anchos[i], _anchos[(i + 1) % n], f)]


func _normal_en(i: int) -> Vector3:
	var n := _pts.size()
	var pa := _pts[(i - 1 + n) % n]
	var p := _pts[i]
	var pb := _pts[(i + 1) % n]
	var d := (p - pa) + (pb - p)
	if d.length() < 0.001:
		d = pb - pa
	var nv := Vector3(-d.z, 0.0, d.x)
	if nv.length() < 0.001:
		nv = Vector3(1, 0, 0)
	return nv.normalized()


# ---------------------------------------------------------------
# MATERIALES
# ---------------------------------------------------------------
func _mat(color: Color, metal: float = 0.0, rugosidad: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rugosidad
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _emisivo(color: Color, energia: float, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c := Color(color.r, color.g, color.b, alpha)
	m.albedo_color = c
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energia
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _crear_materiales() -> void:
	_asfalto = _mat(Color(0.12, 0.12, 0.14), 0.6, 0.4)
	_roca = _mat(Color(0.35, 0.12, 0.07), 0.0, 0.95)
	_roca2 = _mat(Color(0.2, 0.08, 0.06), 0.0, 1.0)
	_metal = _mat(Color(0.25, 0.28, 0.32), 0.8, 0.35)
	_cian = _emisivo(Color(0.2, 0.7, 1.0), 3.0)
	_blanco = _emisivo(Color(0.9, 0.95, 1.0), 1.5)
	_puerta = _emisivo(Color(0.2, 0.7, 1.0), 2.0, 0.25)
	_meta = _emisivo(Color(0.2, 1.0, 0.4), 2.5, 0.3)


# ---------------------------------------------------------------
# ENTORNO Y SUELO
# ---------------------------------------------------------------
func _construir_entorno() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.03, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.6, 0.4)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.2, 0.1)
	env.fog_density = 0.003
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sol := DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sol.light_color = Color(1.0, 0.75, 0.6)
	sol.light_energy = 1.3
	sol.shadow_enabled = true
	add_child(sol)


func _construir_suelo() -> void:
	var plano := PlaneMesh.new()
	plano.size = Vector2(2600, 2600)
	var mi := MeshInstance3D.new()
	mi.name = "Suelo"
	mi.mesh = plano
	mi.material_override = _mat(Color(0.45, 0.16, 0.08), 0.0, 0.95)
	mi.position = Vector3(0.0, -0.15, 0.0)
	add_child(mi)


# ---------------------------------------------------------------
# PISTA (cinta con ancho variable: ancha en rectas, angosta en V)
# ---------------------------------------------------------------
func _cinta(centros: PackedVector3Array, anchos: PackedFloat32Array, y: float, mat: Material) -> MeshInstance3D:
	var n := centros.size()
	var izq := PackedVector3Array()
	var der := PackedVector3Array()
	izq.resize(n)
	der.resize(n)
	for i in n:
		var pa: Vector3 = centros[(i - 1 + n) % n]
		var p: Vector3 = centros[i]
		var pb: Vector3 = centros[(i + 1) % n]
		var d: Vector3 = (p - pa) + (pb - p)
		if d.length() < 0.001:
			d = pb - pa
		var nv := Vector3(-d.z, 0.0, d.x)
		if nv.length() < 0.001:
			nv = Vector3(1, 0, 0)
		nv = nv.normalized()
		var mitad := anchos[i] * 0.5
		izq[i] = p - nv * mitad + Vector3(0, y, 0)
		der[i] = p + nv * mitad + Vector3(0, y, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	st.set_normal(Vector3.UP)
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(izq[i])
		st.add_vertex(der[i])
		st.add_vertex(izq[j])
		st.add_vertex(der[i])
		st.add_vertex(der[j])
		st.add_vertex(izq[j])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi


func _construir_pista() -> void:
	var pista := _cinta(_pts, _anchos, 0.0, _asfalto)
	pista.name = "Pista"
	add_child(pista)

	# Rieles cian en los bordes (siguen el mismo trazado)
	var n := _pts.size()
	var cl := PackedVector3Array()
	var cr := PackedVector3Array()
	var aw := PackedFloat32Array()
	cl.resize(n)
	cr.resize(n)
	aw.resize(n)
	for i in n:
		var nv := _normal_en(i)
		var off := _anchos[i] * 0.5 - 0.7
		cl[i] = _pts[i] - nv * off
		cr[i] = _pts[i] + nv * off
		aw[i] = 1.4
	var ril := _cinta(cl, aw, 0.06, _cian)
	ril.name = "RielIzq"
	add_child(ril)
	var rir := _cinta(cr, aw, 0.06, _cian)
	rir.name = "RielDer"
	add_child(rir)

	# Línea de salida sobre la pista (en s=0)
	var m := _muestrear(0.0)
	var t: Vector3 = m[1]
	var linea := MeshInstance3D.new()
	linea.name = "Salida"
	var caja := BoxMesh.new()
	caja.size = Vector3(float(m[2]) + 1.0, 0.1, 2.5)
	linea.mesh = caja
	linea.material_override = _blanco
	linea.position = m[0] + Vector3(0, 0.12, 0)
	linea.rotation.y = atan2(-t.x, -t.z)
	add_child(linea)


# ---------------------------------------------------------------
# PUERTAS DE CONTROL (verdes la meta, azules el resto)
# ---------------------------------------------------------------
func _construir_puertas() -> void:
	var nodos := Node3D.new()
	nodos.name = "Puertas"
	add_child(nodos)
	for k in num_puertas:
		var m := _muestrear(_total * float(k) / float(num_puertas))
		var centro: Vector3 = m[0]
		var t: Vector3 = m[1]
		var w := float(m[2])
		var es_meta := (k == 0)

		var puerta := Area3D.new()
		puerta.name = "Meta" if es_meta else "Puerta%d" % k
		puerta.position = centro
		puerta.rotation.y = atan2(-t.x, -t.z)
		nodos.add_child(puerta)

		var panel := MeshInstance3D.new()
		panel.name = "Panel"
		var pm := BoxMesh.new()
		pm.size = Vector3(w + 2.0, 3.5, 0.5)
		panel.mesh = pm
		panel.material_override = _meta if es_meta else _puerta
		panel.position = Vector3(0.0, 3.2, 0.0)
		puerta.add_child(panel)

		for lado in [-1.0, 1.0]:
			var poste := MeshInstance3D.new()
			poste.name = "Poste"
			var cm := BoxMesh.new()
			cm.size = Vector3(0.6, 5.0, 0.6)
			poste.mesh = cm
			poste.material_override = _metal
			poste.position = Vector3(lado * (w * 0.5 + 1.0), 2.5, 0.0)
			puerta.add_child(poste)

		var franja := MeshInstance3D.new()
		franja.name = "Franja"
		var fm := BoxMesh.new()
		fm.size = Vector3(w + 1.0, 0.1, 2.0)
		franja.mesh = fm
		franja.material_override = _meta if es_meta else _blanco
		franja.position = Vector3(0.0, 0.12, 0.0)
		puerta.add_child(franja)

		var col := CollisionShape3D.new()
		col.name = "Colision"
		var forma := BoxShape3D.new()
		forma.size = Vector3(w + 2.0, 5.0, 3.0)
		col.shape = forma
		col.position = Vector3(0.0, 3.0, 0.0)
		puerta.add_child(col)


# ---------------------------------------------------------------
# DECORADO: pilón central, rocas, plataformas y luces
# ---------------------------------------------------------------
func _lejos_de_pista(p: Vector3, margen: float) -> bool:
	var n := _pts.size()
	var k := 0
	while k < n:
		var q := _pts[k]
		var dx := p.x - q.x
		var dz := p.z - q.z
		if dx * dx + dz * dz < margen * margen:
			return false
		k += 3
	return true


func _construir_decorado() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	var pilon := MeshInstance3D.new()
	pilon.name = "Pilon"
	var pm := BoxMesh.new()
	pm.size = Vector3(8.0, 10.0, 8.0)
	pilon.mesh = pm
	pilon.material_override = _metal
	pilon.position = Vector3(0.0, 4.0, 0.0)
	add_child(pilon)
	var punta := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 2.0
	sm.height = 4.0
	punta.mesh = sm
	punta.material_override = _cian
	punta.position = Vector3(0.0, 10.5, 0.0)
	add_child(punta)

	var rocas := Node3D.new()
	rocas.name = "Rocas"
	add_child(rocas)
	var puestas := 0
	var intentos := 0
	while puestas < 22 and intentos < 200:
		intentos += 1
		var pos := Vector3(rng.randf_range(-650.0, 650.0), 0.0, rng.randf_range(-1150.0, 1150.0))
		if not _lejos_de_pista(pos, 55.0):
			continue
		var escala := rng.randf_range(1.5, 4.0)
		var roca := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 1.0
		em.height = 2.0
		em.radial_segments = 12
		em.rings = 6
		roca.mesh = em
		roca.material_override = _roca if puestas % 2 == 0 else _roca2
		roca.position = pos + Vector3(0.0, -0.15 + 0.35 * escala, 0.0)
		roca.scale = Vector3(escala, escala * 0.55, escala * 0.9)
		roca.rotation.y = rng.randf_range(0.0, TAU)
		rocas.add_child(roca)
		puestas += 1

	for dato in [[rx + 80.0, 200.0], [-rx - 80.0, -200.0]]:
		var plat := MeshInstance3D.new()
		plat.name = "Plataforma"
		var bm := BoxMesh.new()
		bm.size = Vector3(10.0, 1.0, 8.0)
		plat.mesh = bm
		plat.material_override = _metal
		plat.position = Vector3(dato[0], 2.0, dato[1])
		add_child(plat)
		var tira := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(7.0, 0.15, 0.6)
		tira.mesh = tm
		tira.material_override = _cian
		tira.position = Vector3(dato[0], 2.6, dato[1])
		add_child(tira)

	for f in [[rx, 350.0], [rx, -350.0], [-rx, 350.0], [-rx, -350.0]]:
		var omni := OmniLight3D.new()
		omni.light_color = Color(0.3, 0.7, 1.0)
		omni.light_energy = 2.0
		omni.omni_range = 40.0
		omni.position = Vector3(f[0], 5.0, f[1])
		add_child(omni)
	var meta_luz := OmniLight3D.new()
	meta_luz.light_color = Color(0.3, 1.0, 0.5)
	meta_luz.light_energy = 2.5
	meta_luz.omni_range = 40.0
	meta_luz.position = Vector3(rx, 5.0, -rz)
	add_child(meta_luz)
