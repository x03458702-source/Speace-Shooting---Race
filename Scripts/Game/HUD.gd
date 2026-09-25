class_name HUDJuego
extends CanvasLayer
## Interfaz de Usuario Sci-Fi (Sección 13 y 26)
## Muestra vidas (❤️ ❤️ ❤️), posición (2/4), vuelta, puntaje, velocímetro,
## comodín almacenado con indicador visual, cuenta atrás y pantalla de victoria/trofeos.

var _label_vidas: Label
var _label_posicion: Label
var _label_vuelta: Label
var _label_puntos: Label
var _label_velocidad: Label

var _panel_comodin: PanelContainer
var _label_comodin_icono: Label
var _label_comodin_nombre: Label
var _label_comodin_hint: Label

var _label_cuenta_atras: Label
var _panel_resultados: PanelContainer
var _label_res_titulo: Label
var _label_res_pos: Label
var _label_res_tiempo: Label
var _label_res_puntos: Label
var _label_res_estrellas: Label
var _label_res_trofeo: Label

var _jugador_ref: Node = null
var _manager_ref: Node = null

func _ready() -> void:
	_construir_interfaz()

func vincular(jugador: Node, manager: Node) -> void:
	_jugador_ref = jugador
	_manager_ref = manager

	if jugador != null:
		if jugador.has_signal("vidas_cambiadas"):
			jugador.vidas_cambiadas.connect(actualizar_vidas)
		if jugador.has_signal("comodin_cambiado"):
			jugador.comodin_cambiado.connect(actualizar_comodin)

	if manager != null:
		if manager.has_signal("cuenta_atras_actualizada"):
			manager.cuenta_atras_actualizada.connect(mostrar_cuenta_atras)
		if manager.has_signal("posiciones_actualizadas"):
			manager.posiciones_actualizadas.connect(actualizar_posicion)
		if manager.has_signal("puntos_actualizados"):
			manager.puntos_actualizados.connect(actualizar_puntos)
		if manager.has_signal("vuelta_cambiada"):
			manager.vuelta_cambiada.connect(actualizar_vuelta)
		if manager.has_signal("carrera_finalizada"):
			manager.carrera_finalizada.connect(mostrar_pantalla_resultados)

func _process(_delta: float) -> void:
	# Actualizar velocímetro en tiempo real
	if _jugador_ref != null and is_instance_valid(_jugador_ref) and _jugador_ref.has_method("get"):
		var vel: Vector3 = _jugador_ref.get("velocity")
		var kmh := int(vel.length() * 4.2)
		_label_velocidad.text = "%d KM/H" % kmh

	# Atajo de teclado para reiniciar al finalizar
	if _panel_resultados.visible and Input.is_physical_key_pressed(KEY_R):
		get_tree().reload_current_scene()

func _construir_interfaz() -> void:
	var control_raiz := Control.new()
	control_raiz.name = "HUDControl"
	control_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	control_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control_raiz)

	# -----------------------------------------------------------
	# 1. BARRA SUPERIOR
	# -----------------------------------------------------------
	var barra_sup := HBoxContainer.new()
	barra_sup.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra_sup.offset_left = 30
	barra_sup.offset_top = 20
	barra_sup.offset_right = -30
	barra_sup.offset_bottom = 80
	barra_sup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_raiz.add_child(barra_sup)

	# Vidas (❤️ ❤️ ❤️)
	_label_vidas = Label.new()
	_label_vidas.text = "❤️❤️❤️"
	_label_vidas.add_theme_font_size_override("font_size", 28)
	_label_vidas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_sup.add_child(_label_vidas)

	# Posición y Vueltas (Centro)
	var caja_centro := VBoxContainer.new()
	caja_centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_sup.add_child(caja_centro)

	_label_posicion = Label.new()
	_label_posicion.text = "POSICIÓN 1 / 4"
	_label_posicion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_posicion.add_theme_font_size_override("font_size", 34)
	_label_posicion.add_theme_color_override("font_color", Color(0.15, 0.85, 1.0))
	caja_centro.add_child(_label_posicion)

	_label_vuelta = Label.new()
	_label_vuelta.text = "VUELTA 1 / 3"
	_label_vuelta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_vuelta.add_theme_font_size_override("font_size", 20)
	_label_vuelta.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	caja_centro.add_child(_label_vuelta)

	# Puntos y Velocímetro (Derecha)
	var caja_der := VBoxContainer.new()
	caja_der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_sup.add_child(caja_der)

	_label_puntos = Label.new()
	_label_puntos.text = "PUNTAJE: 0"
	_label_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_puntos.add_theme_font_size_override("font_size", 26)
	_label_puntos.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	caja_der.add_child(_label_puntos)

	_label_velocidad = Label.new()
	_label_velocidad.text = "120 KM/H"
	_label_velocidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label_velocidad.add_theme_font_size_override("font_size", 20)
	_label_velocidad.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	caja_der.add_child(_label_velocidad)

	# -----------------------------------------------------------
	# 2. CASILLA DE COMODÍN (Inferior derecha)
	# -----------------------------------------------------------
	_panel_comodin = PanelContainer.new()
	_panel_comodin.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel_comodin.offset_left = -270
	_panel_comodin.offset_top = -140
	_panel_comodin.offset_right = -30
	_panel_comodin.offset_bottom = -30
	control_raiz.add_child(_panel_comodin)

	var estilo_box := StyleBoxFlat.new()
	estilo_box.bg_color = Color(0.04, 0.06, 0.12, 0.85)
	estilo_box.border_color = Color(0.15, 0.7, 1.0)
	estilo_box.set_border_width_all(3)
	estilo_box.set_corner_radius_all(10)
	estilo_box.set_content_margin_all(10)
	_panel_comodin.add_theme_stylebox_override("panel", estilo_box)

	var caja_item := VBoxContainer.new()
	_panel_comodin.add_child(caja_item)

	var fila_item := HBoxContainer.new()
	caja_item.add_child(fila_item)

	_label_comodin_icono = Label.new()
	_label_comodin_icono.text = "—"
	_label_comodin_icono.add_theme_font_size_override("font_size", 34)
	fila_item.add_child(_label_comodin_icono)

	_label_comodin_nombre = Label.new()
	_label_comodin_nombre.text = "SIN COMODÍN"
	_label_comodin_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label_comodin_nombre.add_theme_font_size_override("font_size", 17)
	_label_comodin_nombre.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	fila_item.add_child(_label_comodin_nombre)

	_label_comodin_hint = Label.new()
	_label_comodin_hint.text = "[ESPACIO / CLIC DER] USAR"
	_label_comodin_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_comodin_hint.add_theme_font_size_override("font_size", 12)
	_label_comodin_hint.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8))
	caja_item.add_child(_label_comodin_hint)

	# -----------------------------------------------------------
	# 3. TEXTO DE CUENTA ATRÁS / ALERTAS (Centro de pantalla)
	# -----------------------------------------------------------
	_label_cuenta_atras = Label.new()
	_label_cuenta_atras.set_anchors_preset(Control.PRESET_CENTER)
	_label_cuenta_atras.offset_left = -250
	_label_cuenta_atras.offset_top = -60
	_label_cuenta_atras.offset_right = 250
	_label_cuenta_atras.offset_bottom = 60
	_label_cuenta_atras.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_cuenta_atras.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_cuenta_atras.add_theme_font_size_override("font_size", 72)
	_label_cuenta_atras.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	control_raiz.add_child(_label_cuenta_atras)

	# -----------------------------------------------------------
	# 4. MODAL DE RESULTADOS / ESTRELLAS / TROFEO
	# -----------------------------------------------------------
	_panel_resultados = PanelContainer.new()
	_panel_resultados.set_anchors_preset(Control.PRESET_CENTER)
	_panel_resultados.offset_left = -300
	_panel_resultados.offset_top = -220
	_panel_resultados.offset_right = 300
	_panel_resultados.offset_bottom = 220
	_panel_resultados.visible = false
	control_raiz.add_child(_panel_resultados)

	var estilo_res := StyleBoxFlat.new()
	estilo_res.bg_color = Color(0.06, 0.08, 0.16, 0.96)
	estilo_res.border_color = Color(0.95, 0.8, 0.15)
	estilo_res.set_border_width_all(4)
	estilo_res.set_corner_radius_all(14)
	estilo_res.set_content_margin_all(22)
	_panel_resultados.add_theme_stylebox_override("panel", estilo_res)

	var caja_res := VBoxContainer.new()
	caja_res.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_resultados.add_child(caja_res)

	_label_res_titulo = Label.new()
	_label_res_titulo.text = "¡CARRERA FINALIZADA!"
	_label_res_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_titulo.add_theme_font_size_override("font_size", 30)
	_label_res_titulo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	caja_res.add_child(_label_res_titulo)

	_label_res_pos = Label.new()
	_label_res_pos.text = "1º LUGAR"
	_label_res_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_pos.add_theme_font_size_override("font_size", 38)
	_label_res_pos.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	caja_res.add_child(_label_res_pos)

	_label_res_tiempo = Label.new()
	_label_res_tiempo.text = "Tiempo: 01:24.50"
	_label_res_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_tiempo.add_theme_font_size_override("font_size", 18)
	caja_res.add_child(_label_res_tiempo)

	_label_res_puntos = Label.new()
	_label_res_puntos.text = "Puntos: 2,450"
	_label_res_puntos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_puntos.add_theme_font_size_override("font_size", 22)
	_label_res_puntos.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	caja_res.add_child(_label_res_puntos)

	_label_res_estrellas = Label.new()
	_label_res_estrellas.text = "⭐ ⭐ ⭐"
	_label_res_estrellas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_estrellas.add_theme_font_size_override("font_size", 42)
	caja_res.add_child(_label_res_estrellas)

	_label_res_trofeo = Label.new()
	_label_res_trofeo.text = "🏆 ¡TROFEO OBTENIDO!"
	_label_res_trofeo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_res_trofeo.add_theme_font_size_override("font_size", 22)
	_label_res_trofeo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	caja_res.add_child(_label_res_trofeo)

	var label_reiniciar := Label.new()
	label_reiniciar.text = "\n[Presiona R para volver a jugar]"
	label_reiniciar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_reiniciar.add_theme_font_size_override("font_size", 14)
	label_reiniciar.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	caja_res.add_child(label_reiniciar)

# -----------------------------------------------------------
# MÉTODOS DE ACTUALIZACIÓN
# -----------------------------------------------------------
func actualizar_vidas(vidas_actuales: int, max_v: int) -> void:
	var texto := ""
	for i in max_v:
		if i < vidas_actuales:
			texto += "❤️ "
		else:
			texto += "🖤 "
	_label_vidas.text = texto.strip_edges()

func actualizar_posicion(pos: int, total: int) -> void:
	_label_posicion.text = "POSICIÓN %d / %d" % [pos, total]
	if pos == 1:
		_label_posicion.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	else:
		_label_posicion.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0))

func actualizar_vuelta(vuelta: int, total: int) -> void:
	_label_vuelta.text = "VUELTA %d / %d" % [vuelta, total]
	if vuelta == total:
		_label_vuelta.text = "VUELTA %d / %d - ¡ÚLTIMA VUELTA!" % [vuelta, total]
		_label_vuelta.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

func actualizar_puntos(puntos: int) -> void:
	_label_puntos.text = "PUNTAJE: %d" % puntos

func actualizar_comodin(tipo: int, cargas: int) -> void:
	var icono: String = PowerUpTypes.ICONOS.get(tipo, "—")
	var nombre: String = PowerUpTypes.NOMBRES.get(tipo, "SIN COMODÍN")
	var color_item: Color = PowerUpTypes.COLORES.get(tipo, Color(0.3, 0.3, 0.4))

	if tipo == PowerUpTypes.Type.CANON and cargas > 0:
		nombre += " (%d)" % cargas

	_label_comodin_icono.text = icono
	_label_comodin_nombre.text = nombre
	_label_comodin_nombre.add_theme_color_override("font_color", color_item)

func mostrar_cuenta_atras(texto: String) -> void:
	_label_cuenta_atras.text = texto
	if texto == "¡DESPEGUE!":
		_label_cuenta_atras.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
	else:
		_label_cuenta_atras.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

func mostrar_pantalla_resultados(datos: Dictionary) -> void:
	_panel_resultados.visible = true
	var victoria: bool = datos.get("victoria", false)

	if not victoria:
		_label_res_titulo.text = "¡NAVE DESTRUIDA!"
		_label_res_titulo.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		_label_res_pos.text = "ELIMINADO"
		_label_res_estrellas.text = "❌"
		_label_res_trofeo.visible = false
	else:
		var pos: int = datos.get("posicion", 1)
		_label_res_titulo.text = "¡CARRERA COMPLETADA!"
		_label_res_pos.text = "%dº LUGAR" % pos

		var num_estrellas: int = datos.get("estrellas", 0)
		var txt_estrellas := ""
		for i in 3:
			txt_estrellas += "⭐ " if i < num_estrellas else "☆ "
		_label_res_estrellas.text = txt_estrellas.strip_edges()

		var gano_trofeo: bool = datos.get("trofeo", false)
		_label_res_trofeo.visible = gano_trofeo

	var tiempo: float = datos.get("tiempo", 0.0)
	var minutos := int(tiempo / 60.0)
	var segundos := int(tiempo) % 60
	var centesimas := int((tiempo - int(tiempo)) * 100.0)
	_label_res_tiempo.text = "Tiempo: %02d:%02d.%02d" % [minutos, segundos, centesimas]
	_label_res_puntos.text = "Puntos: %d" % datos.get("puntos", 0)
