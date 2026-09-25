class_name PowerUpTypes
extends RefCounted
## Definición de tipos de comodines y balance oficial (Sección 14 y 17)
## Probabilidades: 30% Escudo, 30% Cañón, 20% Bomba, 20% Aceite.

enum Type {
	NONE,
	ESCUDO,   # 30% - Absorbe 100% de daño del primer impacto o dura 8 s
	CANON,    # 30% - 3 disparos frontales potentes, destruye obstáculos o reduce 40% velocidad rival 2 s
	BOMBA,    # 20% - Onda radial destructiva de área (200 px / ~35 m)
	ACEITE    # 20% - Trampa trasera persistente, causa giro y reduce 60% velocidad 2.5 s
}

const NOMBRES = {
	Type.NONE: "VACÍO",
	Type.ESCUDO: "ESCUDO ESPACIAL",
	Type.CANON: "CAÑÓN LÁSER",
	Type.BOMBA: "BOMBA DE ÁREA",
	Type.ACEITE: "ACEITE ESPACIAL"
}

const COLORES = {
	Type.NONE: Color(0.3, 0.3, 0.4, 0.5),
	Type.ESCUDO: Color(0.15, 0.7, 1.0),     # Cian brillante
	Type.CANON: Color(1.0, 0.25, 0.15),    # Rojo combate
	Type.BOMBA: Color(1.0, 0.85, 0.1),     # Amarillo energía
	Type.ACEITE: Color(0.7, 0.15, 0.95)    # Violeta cósmico
}

const ICONOS = {
	Type.NONE: "—",
	Type.ESCUDO: "🛡️",
	Type.CANON: "⚡",
	Type.BOMBA: "💣",
	Type.ACEITE: "🛢️"
}

## Obtiene un comodín aleatorio basado en las probabilidades oficiales
static func obtener_aleatorio() -> Type:
	var roll := randf() * 100.0
	if roll < 30.0:
		return Type.ESCUDO
	elif roll < 60.0:
		return Type.CANON
	elif roll < 80.0:
		return Type.BOMBA
	else:
		return Type.ACEITE
