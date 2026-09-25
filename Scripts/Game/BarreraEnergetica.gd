class_name BarreraEnergetica
extends Area3D
## Barrera Energética 3D (Sección 22)
## Bloquea un carril del circuito mediante un campo de fuerza luminoso.
## Obliga al piloto a maniobrar hacia el carril libre o sufrir impacto.

@export var ancho: float = 14.0
@export var altura: float = 5.0

var _malla_rayo: MeshInstance3D
var _mat_rayo: StandardMaterial3D
var _tiempo: float = 0.0

func _ready() -> void:
	collision_layer = 4       # Capa 3 (Obstáculos)
	collision_mask = 1 | 2    # Jugador y Rivales
	
	_construir_visuales()
	_crear_colision()
	
	body_entered.connect(_al_colisionar_cuerpo)
	area_entered.connect(_al_colisionar_area)

func _construir_visuales() -> void:
	# Dos postes metálicos en los extremos
	for lado in [-1.0, 1.0]:
		var poste := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.4
		cm.bottom_radius = 0.5
		cm.height = altura
		poste.mesh = cm
		
		var mat_poste := StandardMaterial3D.new()
		mat_poste.albedo_color = Color(0.2, 0.25, 0.3)
		mat_poste.metallic = 0.8
		mat_poste.roughness = 0.3
		poste.material_override = mat_poste
		poste.position = Vector3(lado * (ancho * 0.5), altura * 0.5, 0)
		add_child(poste)
		
		# Emisor en la punta del poste
		var foco := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		foco.mesh = sm
		var mat_foco := StandardMaterial3D.new()
		mat_foco.albedo_color = Color(0.1, 0.8, 1.0)
		mat_foco.emission_enabled = true
		mat_foco.emission = Color(0.1, 0.85, 1.0)
		mat_foco.emission_energy_multiplier = 4.0
		foco.material_override = mat_foco
		foco.position = Vector3(lado * (ancho * 0.5), altura, 0)
		add_child(foco)

	# Campo de energía central (lámina translúcida brillante)
	_malla_rayo = MeshInstance3D.new()
	var plano := BoxMesh.new()
	plano.size = Vector3(ancho, altura * 0.85, 0.25)
	_malla_rayo.mesh = plano
	
	_mat_rayo = StandardMaterial3D.new()
	_mat_rayo.albedo_color = Color(0.1, 0.75, 1.0, 0.5)
	_mat_rayo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_rayo.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_rayo.emission_enabled = true
	_mat_rayo.emission = Color(0.15, 0.8, 1.0)
	_mat_rayo.emission_energy_multiplier = 3.5
	_malla_rayo.material_override = _mat_rayo
	_malla_rayo.position = Vector3(0, altura * 0.45, 0)
	add_child(_malla_rayo)

func _crear_colision() -> void:
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(ancho, altura, 1.5)
	col.shape = forma
	col.position = Vector3(0, altura * 0.5, 0)
	add_child(col)

func _process(delta: float) -> void:
	_tiempo += delta * 6.0
	# Pulsación de energía
	var pulso := 2.5 + sin(_tiempo) * 1.5
	_mat_rayo.emission_energy_multiplier = pulso

func _al_colisionar_cuerpo(cuerpo: Node3D) -> void:
	_impactar_nave(cuerpo)

func _al_colisionar_area(area: Area3D) -> void:
	_impactar_nave(area.get_parent())

func _impactar_nave(nodo: Node) -> void:
	if nodo == null:
		return
	if nodo.has_method("recibir_dano"):
		nodo.recibir_dano(1, global_position)
