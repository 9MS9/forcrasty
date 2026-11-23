class_name LegPhaseController
extends RefCounted

enum Phase { STANCE, SWING }

var phase: Phase = Phase.STANCE
var phase_time: float = 0.0
var swing_duration: float = 0.5
var k_scale_current: float = 1.0
var k_scale_stance: float = 1.0
var k_scale_swing: float = 0.3
var k_transition_time: float = 0.1

var drivers: Array = []
var foot: FootBody

# Фиксированная траектория шага для этой ноги (отклонения в радианах)
var swing_trajectory := {
	"hip_abduct_dev": 0.0,
	"hip_pitch_dev": -0.5,   # Вперёд
	"knee_dev": 0.85,        # Подъём колена
	"ankle_dev": -0.35       # Компенсация
}

var stance_deviations := {
	"hip_abduct_dev": 0.0,
	"hip_pitch_dev": 0.0,
	"knee_dev": 0.0,
	"ankle_dev": 0.0
}

var _was_airborne: bool = false

func _init(joint_drivers: Array, foot_body: FootBody) -> void:
	drivers = joint_drivers
	foot = foot_body

func start_swing() -> void:
	if phase == Phase.SWING:
		return
	phase = Phase.SWING
	phase_time = 0.0
	_was_airborne = false
	for drv in drivers:
		for c in drv.configs:
			c.slew_rate_deg = 180.0

func update(delta: float) -> void:
	if phase == Phase.SWING:
		phase_time += delta
		k_scale_current = move_toward(k_scale_current, k_scale_swing, delta / k_transition_time)
		
		if not foot.stance:
			_was_airborne = true
		
		var t := phase_time / swing_duration
		if t >= 1.0:
			_finish_swing()
		else:
			var progress := sin(t * PI)
			var dev := {
				"hip_abduct_dev": swing_trajectory["hip_abduct_dev"] * progress,
				"hip_pitch_dev": swing_trajectory["hip_pitch_dev"] * progress,
				"knee_dev": swing_trajectory["knee_dev"] * progress,
				"ankle_dev": swing_trajectory["ankle_dev"] * progress
			}
			_apply_targets(dev)
			for drv in drivers:
				drv.k_scale = k_scale_current
				
	elif phase == Phase.STANCE:
		k_scale_current = move_toward(k_scale_current, k_scale_stance, delta / k_transition_time)
		_apply_targets(stance_deviations)
		for drv in drivers:
			drv.k_scale = k_scale_current

func check_foot_contact() -> void:
	if phase == Phase.SWING and _was_airborne and foot.stance:
		_finish_swing()

func _finish_swing() -> void:
	phase = Phase.STANCE
	phase_time = 0.0
	for drv in drivers:
		for c in drv.configs:
			c.slew_rate_deg = 90.0
	stance_deviations = {
		"hip_abduct_dev": 0.0,
		"hip_pitch_dev": 0.0,
		"knee_dev": 0.0,
		"ankle_dev": 0.0
	}

func _apply_targets(dev: Dictionary) -> void:
	if drivers.size() >= 3:
		drivers[0].configs[0].target_deg = rad_to_deg(dev["hip_pitch_dev"])
		drivers[0].configs[1].target_deg = rad_to_deg(dev["hip_abduct_dev"])
		drivers[1].configs[0].target_deg = rad_to_deg(dev["knee_dev"])
		drivers[2].configs[0].target_deg = rad_to_deg(dev["ankle_dev"])
