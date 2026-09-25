extends Node3D
## LÁSER de la nave. Lo crea nave.gd cada vez que disparas.
## Núcleo blanco + halo rojo, viaja al frente de la nave y al impactar
## (capa 3 = futuros obstáculos) deja un destello y se destruye.

var velocidad: float = 380.0   # casi instantáneo: zap recto que no alcanza a curvarse
var vida: float = 0.25         # chispazo corto (~95 m): no dibuja la curva en el aire
var dano: int = 1              # daño por impacto (lo usará el sistema de combate)


func _ready() -> void:
	add_to_group("laser")
	_construir()

	# Detector de impactos. Máscara 4 (capa 3): IGNORA la propia nave (capa 1)
	# y las puertas (áreas en capa 1). Los futuros obstáculos irán en capa 3.
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	var col := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.6
	col.shape = esfera
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_al_impactar.bind(area))
	area.area_entered.connect(_al_impactar.bind(area))


func _construir() -> void:
	var nucleo := MeshInstance3D.new()
	var bn := BoxMesh.new()
	bn.size = Vector3(0.14, 0.14, 1.6)
	nucleo.mesh = bn
	nucleo.material_override = _brillo(Color(1.0, 1.0, 1.0), 6.0)
	add_child(nucleo)

	var halo := MeshInstance3D.new()
	var bh := BoxMesh.new()
	bh.size = Vector3(0.28, 0.28, 1.1)
	halo.mesh = bh
	halo.material_override = _brillo(Color(1.0, 0.15, 0.15), 4.0)
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
	# Solución a los rayos que se salen del mapa: se apagan solos al
	# expirar, al tocar el suelo (con destello) o al cruzar los límites.
	if vida <= 0.0 or absf(global_position.x) > 700.0 or absf(global_position.z) > 950.0 or global_position.y > 80.0:
		queue_free()
		return
	if global_position.y < 0.8:
		_destello(global_position, Color(0.6, 0.3, 0.15))
		queue_free()


func _al_impactar(_nodo: Variant, area: Area3D) -> void:
	_destello(global_position, Color(1.0, 0.4, 0.2))
	area.set_deferred("monitoring", false)
	queue_free()


func _destello(pos: Vector3, color: Color) -> void:
	var chispa := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	chispa.mesh = sm
	chispa.material_override = _brillo(color, 5.0)
	get_parent().add_child(chispa)
	chispa.global_position = pos
	var tw := chispa.create_tween()
	tw.tween_property(chispa, "scale", Vector3.ONE * 3.0, 0.15)
	tw.tween_callback(chispa.queue_free)
