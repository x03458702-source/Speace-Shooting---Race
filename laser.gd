extends Area3D
## Script para los proyectiles de láser

@export var velocidad: float = 30.0
@export var tiempo_vida: float = 3.0
var disparo_por: Node3D = null  # Para evitar autodestruirse al disparar

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Malla visual del láser (cilindro rojo brillante)
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.08
	c.height = 0.8
	mi.mesh = c
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.1)
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	mi.rotation_degrees.x = 90.0
	add_child(mi)

	# Colisión del láser
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.2, 0.8)
	col.shape = shape
	add_child(col)

func _physics_process(delta: float) -> void:
	# El láser avanza hacia adelante en su eje Z local (-Z)
	position -= transform.basis.z * velocidad * delta
	tiempo_vida -= delta
	if tiempo_vida <= 0.0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	# Si choca con una nave y no es la nave que disparó el láser
	if body.is_in_group("jugador") and body != disparo_por:
		if body.has_method("recibir_dano"):
			body.recibir_dano()
		queue_free()
