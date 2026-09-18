extends Node3D
## LÁSER de la nave. Lo crea nave.gd cada vez que disparas.
## Se dibuja solo, viaja hacia el fondo y se borra a los pocos segundos.

var velocidad: float = 60.0    # qué tan rápido viaja
var vida: float = 3.0          # segundos antes de desaparecer


func _ready() -> void:
	add_to_group("laser")

	var forma := BoxMesh.new()
	forma.size = Vector3(0.08, 0.08, 1.2)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.15)
	mat.emission_energy_multiplier = 4.0

	var malla := MeshInstance3D.new()
	malla.mesh = forma
	malla.material_override = mat
	add_child(malla)


func _process(delta: float) -> void:
	global_position.z -= velocidad * delta
	vida -= delta
	if vida <= 0.0:
		queue_free()
