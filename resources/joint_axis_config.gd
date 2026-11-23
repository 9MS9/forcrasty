class_name JointAxisConfig
extends Resource

enum DriveMode { DISABLED, ENGINE_MOTOR, CUSTOM_PD }

@export var drive_mode: DriveMode = DriveMode.CUSTOM_PD
@export var stiffness: float = 80000.0     # Желаемая жёсткость (Н·м/рад). Драйвер сам ограничит её по устойчивости.
@export var damping_ratio: float = 1.0     # ζ: 1.0 = критическое демпфирование (без колебаний)
@export var max_torque: float = 60000.0
@export var max_speed: float = 2.0
@export var torque_slew: float = 0.3       # Макс. изменение момента за тик, доля от max_torque
@export var slew_rate_deg: float = 90.0
@export var lower_deg: float = -60.0
@export var upper_deg: float = 60.0
@export_range(0.0, 1.0) var damage_scale: float = 1.0
@export var target_deg: float = 0.0
