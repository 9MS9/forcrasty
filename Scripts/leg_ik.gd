class_name LegIK
extends RefCounted
## Численный IK: работает с абсолютными углами, возвращает отклонения от покоя.

var L1: float
var L2: float
var max_reach: float

var rest_hip_abduct: float
var rest_hip_pitch: float
var rest_knee: float
var rest_ankle: float

func _init(l1: float, l2: float, 
		   r_abduct: float, r_pitch: float, r_knee: float, r_ankle: float) -> void:
	L1 = l1
	L2 = l2
	max_reach = l1 + l2 - 0.01
	
	rest_hip_abduct = deg_to_rad(r_abduct)
	rest_hip_pitch = deg_to_rad(r_pitch)
	rest_knee = deg_to_rad(r_knee)
	rest_ankle = deg_to_rad(r_ankle)

func forward_kinematics(abduct: float, pitch: float, knee: float, _ankle: float) -> Vector3:
	var b_hip := Basis(Vector3(0, 0, 1), abduct) * Basis(Vector3(1, 0, 0), pitch)
	var knee_dir := b_hip * Vector3(0, -1, 0)
	var knee_pos := L1 * knee_dir
	
	var b_knee := b_hip * Basis(Vector3(0, 0, 1), knee)
	var foot_dir := b_knee * Vector3(0, -1, 0)
	var foot_pos := knee_pos + L2 * foot_dir
	
	return foot_pos

## Решает IK для абсолютной позиции стопы (относительно бедра в (0,0,0))
func solve(target: Vector3, max_iterations: int = 500, tolerance: float = 0.001) -> Dictionary:
	var result := {
		"hip_abduct_dev": 0.0,
		"hip_pitch_dev": 0.0,
		"knee_dev": 0.0,
		"ankle_dev": 0.0,
		"reachable": true
	}
	
	# Начальное приближение: вычисляем углы для rest позы, затем корректируем
	var angles := [rest_hip_abduct, rest_hip_pitch, rest_knee, rest_ankle]
	
	var rest_pos := forward_kinematics(angles[0], angles[1], angles[2], angles[3])
	print("  IK solve: rest_pos=%s, target=%s, dist=%.3f" % [rest_pos, target, rest_pos.distance_to(target)])
	
	# Проверяем, достижима ли цель
	var dist := target.length()
	if dist > max_reach:
		result["reachable"] = false
		target = target.normalized() * max_reach
	
	for iter in max_iterations:
		var current_pos := forward_kinematics(angles[0], angles[1], angles[2], angles[3])
		var error := target - current_pos
		
		if error.length() < tolerance:
			break
		
		var J := _compute_jacobian(angles)
		var delta := _solve_jacobian(J, error)
		
		for i in 4:
			angles[i] += delta[i] * 0.8  # Увеличенный шаг для сходимости
		
		angles[0] = clampf(angles[0], -1.05, 1.05)
		angles[1] = clampf(angles[1], -0.52, 0.52)
		angles[2] = clampf(angles[2], 0.0, 1.57)
		angles[3] = clampf(angles[3], -0.7, 0.7)
	
	# Возвращаем отклонения от покоя
	result["hip_abduct_dev"] = angles[0] - rest_hip_abduct
	result["hip_pitch_dev"] = angles[1] - rest_hip_pitch
	result["knee_dev"] = angles[2] - rest_knee
	result["ankle_dev"] = angles[3] - rest_ankle
	
	var final_pos := forward_kinematics(angles[0], angles[1], angles[2], angles[3])
	if final_pos.distance_to(target) > 0.05:
		result["reachable"] = false
	
	return result

func _compute_jacobian(angles: Array) -> Array:
	var J := []
	for row in 3:
		J.append([0.0, 0.0, 0.0, 0.0])
	
	var epsilon := 0.001
	var base_pos := forward_kinematics(angles[0], angles[1], angles[2], angles[3])
	
	for col in 4:
		var perturbed := angles.duplicate()
		perturbed[col] += epsilon
		var perturbed_pos := forward_kinematics(perturbed[0], perturbed[1], perturbed[2], perturbed[3])
		var delta := (perturbed_pos - base_pos) / epsilon
		J[0][col] = delta.x
		J[1][col] = delta.y
		J[2][col] = delta.z
	
	return J

func _solve_jacobian(J: Array, error: Vector3) -> Array:
	var delta := [0.0, 0.0, 0.0, 0.0]
	for col in 4:
		delta[col] = J[0][col] * error.x + J[1][col] * error.y + J[2][col] * error.z
	return delta
