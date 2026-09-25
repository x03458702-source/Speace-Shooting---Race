class_name SistemaCarrera
extends Node
## Gestor de Carrera, Puntuación, Posiciones y Estrellas (RF-06, RF-15 a RF-18)
## Controla la cuenta atrás (3, 2, 1, ¡GO!), el orden de llegada en tiempo real,
## las vidas del jugador, los puntos acumulados y las 3 estrellas de recompensa.

signal cuenta_atras_actualizada(texto: String)
signal carrera_iniciada()
signal posiciones_actualizadas(posicion_jugador: int, total_corredores: int)
signal puntos_actualizados(puntos: int)
signal vuelta_cambiada(vuelta_actual: int, total_vueltas: int)
signal carrera_finalizada(resultados: Dictionary)

enum Estado {
	CUENTA_ATRAS,
	EN_CARRERA,
	FINALIZADA,
	DERROTA
}

@export var total_vueltas: int = 3
@export var umbral_puntos_estrella2: int = 1000
@export var tiempo_cuenta_atras: float = 3.5

var estado: Estado = Estado.CUENTA_ATRAS
var tiempo_carrera: float = 0.0
var puntos_jugador: int = 0
var posicion_actual_jugador: int = 1

var jugador: Node = null
var rivales: Array[Node] = []
var todos_los_corredores: Array[Node] = []

var _tiempo_restante_cuenta: float = 3.5
var _ranking_ordenado: Array[Node] = []

func _ready() -> void:
	name = "RaceManager"
	_tiempo_restante_cuenta = tiempo_cuenta_atras

func configurar_participantes(p_jugador: Node, p_rivales: Array) -> void:
	jugador = p_jugador
	rivales.clear()
	for r in p_rivales:
		rivales.append(r)

	todos_los_corredores.clear()
	if jugador != null:
		todos_los_corredores.append(jugador)
		# Deshabilitar controles al inicio durante la cuenta atrás
		if jugador.has_method("set"):
			jugador.set("control_habilitado", false)
		if jugador.has_signal("vuelta_completada"):
			jugador.vuelta_completada.connect(_al_completar_vuelta_jugador)
		if jugador.has_signal("nave_destruida"):
			jugador.nave_destruida.connect(_al_destruirse_jugador)

	for r in rivales:
		todos_los_corredores.append(r)
		if r.has_method("set"):
			r.set("control_habilitado", false)

func _process(delta: float) -> void:
	match estado:
		Estado.CUENTA_ATRAS:
			_procesar_cuenta_atras(delta)
		Estado.EN_CARRERA:
			tiempo_carrera += delta
			_actualizar_rankings()

func _procesar_cuenta_atras(delta: float) -> void:
	_tiempo_restante_cuenta -= delta
	if _tiempo_restante_cuenta > 2.5:
		emit_signal("cuenta_atras_actualizada", "3")
	elif _tiempo_restante_cuenta > 1.5:
		emit_signal("cuenta_atras_actualizada", "2")
	elif _tiempo_restante_cuenta > 0.5:
		emit_signal("cuenta_atras_actualizada", "1")
	elif _tiempo_restante_cuenta > -0.5:
		emit_signal("cuenta_atras_actualizada", "¡DESPEGUE!")
		if estado == Estado.CUENTA_ATRAS:
			_arrancar_carrera()
	else:
		emit_signal("cuenta_atras_actualizada", "")

func _arrancar_carrera() -> void:
	estado = Estado.EN_CARRERA
	for c in todos_los_corredores:
		if is_instance_valid(c) and c.has_method("set"):
			c.set("control_habilitado", true)
	emit_signal("carrera_iniciada")

func _actualizar_rankings() -> void:
	# Ordenar corredores según su progreso continuo total en pista
	_ranking_ordenado = todos_los_corredores.duplicate()
	_ranking_ordenado.sort_custom(func(a, b):
		var prog_a: float = a.get("progreso_total") if is_instance_valid(a) else -1.0
		var prog_b: float = b.get("progreso_total") if is_instance_valid(b) else -1.0
		return prog_a > prog_b
	)

	var nueva_pos: int = _ranking_ordenado.find(jugador) + 1
	if nueva_pos != posicion_actual_jugador and nueva_pos > 0:
		posicion_actual_jugador = nueva_pos
		emit_signal("posiciones_actualizadas", posicion_actual_jugador, todos_los_corredores.size())

func sumar_puntos_jugador(cantidad: int) -> void:
	puntos_jugador += cantidad
	emit_signal("puntos_actualizados", puntos_jugador)

func _al_completar_vuelta_jugador(vuelta: int, total: int) -> void:
	sumar_puntos_jugador(200) # Bonificación de vuelta
	emit_signal("vuelta_cambiada", min(vuelta + 1, total), total)

	if vuelta >= total_vueltas:
		_finalizar_carrera(true)

func _al_destruirse_jugador() -> void:
	_finalizar_carrera(false)

func _finalizar_carrera(completada: bool) -> void:
	if estado == Estado.FINALIZADA or estado == Estado.DERROTA:
		return

	if not completada:
		estado = Estado.DERROTA
		emit_signal("carrera_finalizada", {
			"victoria": false,
			"posicion": posicion_actual_jugador,
			"tiempo": tiempo_carrera,
			"puntos": puntos_jugador,
			"estrellas": 0,
			"trofeo": false,
			"motivo": "Nave destruida sin vidas"
		})
		return

	estado = Estado.FINALIZADA

	# Bonificación por posición final
	var bonus_pos: int = 0
	if posicion_actual_jugador == 1:
		bonus_pos = 1000
	elif posicion_actual_jugador == 2:
		bonus_pos = 600
	elif posicion_actual_jugador == 3:
		bonus_pos = 300
	sumar_puntos_jugador(bonus_pos)

	# Cálculo de Estrellas (Sección 15)
	# Estrella 1: Completar la meta
	var estrella1: bool = true
	# Estrella 2: Superar el umbral de puntos
	var estrella2: bool = puntos_jugador >= umbral_puntos_estrella2
	# Estrella 3: Terminar en primer lugar O completar la carrera sin perder vidas
	var vidas_finales: int = jugador.get("vidas") if is_instance_valid(jugador) else 0
	var estrella3: bool = (posicion_actual_jugador == 1) or (vidas_finales == 3)

	var num_estrellas: int = (1 if estrella1 else 0) + (1 if estrella2 else 0) + (1 if estrella3 else 0)
	var trofeo: bool = (num_estrellas == 3)

	emit_signal("carrera_finalizada", {
		"victoria": true,
		"posicion": posicion_actual_jugador,
		"tiempo": tiempo_carrera,
		"puntos": puntos_jugador,
		"estrellas": num_estrellas,
		"estrella1": estrella1,
		"estrella2": estrella2,
		"estrella3": estrella3,
		"trofeo": trofeo
	})
