class_name ShipStats
extends Resource
## Estadísticas y configuración de comportamiento de naves (ECS - Componente de datos)

@export var max_speed: float = 35.0
@export var reverse_speed: float = -12.0
@export var acceleration: float = 24.0
@export var brake_deceleration: float = 60.0
@export var coast_deceleration: float = 6.0
@export var steering_speed: float = 2.4
@export var steering_response: float = 6.0
@export var max_bank_angle: float = 0.7
@export var hover_height: float = 3.0
@export var linear_damping: float = 0.15
@export var angular_damping: float = 1.5
@export var boost_multiplier: float = 1.5
@export var turn_speed_factor: float = 1.0
@export var mass: float = 1000.0
