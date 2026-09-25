class_name PowerUpComponent
extends Node
## Componente de inventario y estado de comodines (ECS - Sección 10.2)
## Gestiona el comodín almacenado (máx 1), duración del escudo y cargas del cañón.

enum PowerUpType {
	NONE,
	ESCUDO_ESPACIAL,
	CANON_LASER,
	BOMBA_AREA,
	ACEITE_ESPACIAL
}

signal power_up_changed(type: int, charges: int)
signal shield_state_changed(active: bool)

@export var current_power_up: PowerUpType = PowerUpType.NONE
@export var cannon_charges: int = 0
@export var is_shield_active: bool = false
@export var shield_duration: float = 8.0

var _shield_time_left: float = 0.0

func store_power_up(type: PowerUpType) -> bool:
	if current_power_up != PowerUpType.NONE:
		return false

	current_power_up = type
	if type == PowerUpType.CANON_LASER:
		cannon_charges = 3

	emit_signal("power_up_changed", current_power_up, cannon_charges)
	return true

func use_power_up() -> void:
	if current_power_up == PowerUpType.NONE:
		return

	match current_power_up:
		PowerUpType.ESCUDO_ESPACIAL:
			activate_shield()
			current_power_up = PowerUpType.NONE
		PowerUpType.CANON_LASER:
			cannon_charges -= 1
			if cannon_charges <= 0:
				current_power_up = PowerUpType.NONE
		PowerUpType.BOMBA_AREA:
			current_power_up = PowerUpType.NONE
		PowerUpType.ACEITE_ESPACIAL:
			current_power_up = PowerUpType.NONE

	emit_signal("power_up_changed", current_power_up, cannon_charges)

func activate_shield() -> void:
	is_shield_active = true
	_shield_time_left = shield_duration
	emit_signal("shield_state_changed", true)

func deactivate_shield() -> void:
	is_shield_active = false
	_shield_time_left = 0.0
	emit_signal("shield_state_changed", false)

func _process(delta: float) -> void:
	if is_shield_active:
		_shield_time_left -= delta
		if _shield_time_left <= 0.0:
			deactivate_shield()
