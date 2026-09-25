extends Node3D
## LÁSER de combate de la nave (Sección 14 y 23)
## Núcleo brillante + halo luminoso. Puede ser un láser estándar o un disparo
## potenciado de Cañón Láser (3 cargas, ralentiza 40% durante 2 s y destruye obstáculos).

var velocidad: float = 380.0
var vida: float = 0.35
var dano: int = 1
var es_comodin_canon: bool = false
var es_del_jugador: bool = true
var tirador: Node = null

func _ready() -> void:
	add_to_group("laser")
	_construir()

	var area := Area3D.new()
	area.collision_layer = 0
	# Máscara: Obstáculos (capa 3 = 4). Si es del jugador, detecta rivales (capa 2 = 2).
	# Si es de la IA, detecta al jugador (capa 1 = 1).
	var mascara: int = 4
	if es_del_jugador:
		mascara |= 2
	else:
		mascara |= 1
	area.collision_mask = mascara

	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.9 if es_comodin_canon else 0.6
	col.shape = esfera
	area.add_child(col)
	add_child(area)

	area.body_entered.connect(_al_impactar)
	area.area_entered.connect(func(a): _al_impactar(a))

func _construir() -> void:
	var color_nucleo := Color(1.0, 1.0, 1.0)
	var color_halo := Color(1.0, 0.25, 0.1) if es_comodin_canon else Color(1.0, 0.15, 0.15)
	var escala_visual: float = 1.6 if es_comodin_canon else 1.0

	var nucleo := MeshInstance3D.new()
	var bn := BoxMesh.new()
	bn.size = Vector3(0.14, 0.14, 1.6) * escala_visual
	nucleo.mesh = bn
	nucleo.material_override = _brillo(color_nucleo, 7.0 if es_comodin_canon else 6.0)
	add_child(nucleo)

	var halo := MeshInstance3D.new()
	var bh := BoxMesh.new()
	bh.size = Vector3(0.32, 0.32, 1.2) * escala_visual
	halo.mesh = bh
	halo.material_override = _brillo(color_halo, 5.0 if es_comodin_canon else 4.0)
	add_child(halo)

func _brillo(color: Color, energia: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energia
	return m

func _process(delta: float) -> void:
	global_position += -global_transform.basis.z * velocidad * delta
	vida -= delta
	if vida <= 0.0 or absf(global_position.x) > 850.0 or absf(global_position.z) > 1200.0 or global_position.y > 80.0:
		queue_free()
		return
	if global_position.y < 0.8:
		_destello(global_position, Color(0.6, 0.3, 0.15))
		queue_free()

func _al_impactar(objeto: Node) -> void:
	if objeto == null or objeto == tirador:
		return

	var objetivo: Node = objeto
	if objeto is Area3D and objeto.get_parent() != null and not (objeto is ObstaculoAsteroide):
		objetivo = objeto.get_parent()

	if objetivo == tirador:
		return

	# Impacto contra asteroide
	if objetivo.has_method("recibir_dano_laser"):
		objetivo.recibir_dano_laser(2 if es_comodin_canon else 1, es_del_jugador)

	# Impacto contra nave rival o jugador
	if objetivo.has_method("recibir_impacto_laser"):
		objetivo.recibir_impacto_laser(es_comodin_canon, es_del_jugador)
		if es_del_jugador and objetivo.is_in_group("rivales"):
			var rm := get_tree().root.find_child("RaceManager", true, false)
			if rm != null and rm.has_method("sumar_puntos_jugador"):
				rm.sumar_puntos_jugador(150)

	_destello(global_position, Color(1.0, 0.45, 0.1) if es_comodin_canon else Color(1.0, 0.2, 0.2))
	queue_free()

func _destello(pos: Vector3, color: Color) -> void:
	var chispa := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6 if es_comodin_canon else 0.4
	sm.height = 1.2 if es_comodin_canon else 0.8
	chispa.mesh = sm
	chispa.material_override = _brillo(color, 6.0)
	var padre := get_parent()
	if padre != null:
		padre.add_child(chispa)
		chispa.global_position = pos
		var tw := chispa.create_tween()
		tw.tween_property(chispa, "scale", Vector3.ONE * 3.5, 0.15)
		tw.tween_callback(chispa.queue_free)
