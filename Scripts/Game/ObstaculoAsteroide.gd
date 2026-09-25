class_name ObstaculoAsteroide
extends Area3D
## Asteroide destructible del circuito (Sección 22)
## Rota lentamente. Puede ser destruido con disparos láser o con Bomba de Área.
## Al chocar con una nave, inflige 1 de daño (salvo escudo activo) y se fractura.

@export var puntos_recompensa: int = 100
@export var vida: int = 1

var _malla: MeshInstance3D
var _rot_eje: Vector3
var _rot_vel: float

func _ready() -> void:
	collision_layer = 4       # Capa 3 (Obstáculos)
	collision_mask = 1 | 2    # Jugador (1) y Rivales (2)
	
	_construir_visuales()
	_crear_colision()
	
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_rot_eje = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	_rot_vel = rng.randf_range(0.3, 1.2)
	
	body_entered.connect(_al_colisionar_cuerpo)
	area_entered.connect(_al_colisionar_area)

func _construir_visuales() -> void:
	_malla = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.6
	esfera.height = 3.2
	esfera.radial_segments = 14
	esfera.rings = 8
	_malla.mesh = esfera
	
	# Escala ligeramente irregular para simular roca espacial
	var sx := randf_range(0.85, 1.35)
	var sy := randf_range(0.75, 1.25)
	var sz := randf_range(0.85, 1.35)
	_malla.scale = Vector3(sx, sy, sz)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.22, 0.16)
	mat.roughness = 0.95
	mat.metallic = 0.05
	_malla.material_override = mat
	add_child(_malla)

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	var forma := SphereShape3D.new()
	forma.radius = 1.7
	col.shape = forma
	add_child(col)

func _process(delta: float) -> void:
	rotate(_rot_eje, _rot_vel * delta)

func recibir_dano_laser(dano: int, es_del_jugador: bool) -> void:
	vida -= dano
	if vida <= 0:
		_destruir(es_del_jugador)
	else:
		_parpadeo_impacto()

func destruir_por_bomba(es_del_jugador: bool) -> void:
	_destruir(es_del_jugador)

func _destruir(es_del_jugador: bool) -> void:
	if es_del_jugador:
		# Notificar al RaceManager para sumar puntuación
		var rm := get_tree().root.find_child("RaceManager", true, false)
		if rm != null and rm.has_method("sumar_puntos_jugador"):
			rm.sumar_puntos_jugador(puntos_recompensa)
	
	_efecto_explosion()
	queue_free()

func _parpadeo_impacto() -> void:
	var mat: StandardMaterial3D = _malla.material_override
	if mat != null:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.2)
		mat.emission_energy_multiplier = 4.0
		var tw := create_tween()
		tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.15)

func _efecto_explosion() -> void:
	var padre := get_parent()
	if padre == null:
		return
		
	# Pequeños fragmentos de roca en dispersión
	for i in 4:
		var trozo := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.6, 0.6)
		trozo.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.2, 0.1)
		trozo.material_override = mat
		padre.add_child(trozo)
		trozo.global_position = global_position
		
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1), randf_range(-1, 1)).normalized()
		var tw := trozo.create_tween()
		tw.set_parallel(true)
		tw.tween_property(trozo, "global_position", global_position + dir * 6.0, 0.45)
		tw.tween_property(trozo, "scale", Vector3.ZERO, 0.45)
		tw.chain().tween_callback(trozo.queue_free)

func _al_colisionar_cuerpo(cuerpo: Node3D) -> void:
	_impactar_nave(cuerpo)

func _al_colisionar_area(area: Area3D) -> void:
	_impactar_nave(area.get_parent())

func _impactar_nave(nodo: Node) -> void:
	if nodo == null:
		return
	if nodo.has_method("recibir_dano"):
		nodo.recibir_dano(1, global_position)
		_destruir(false)
