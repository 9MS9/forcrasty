extends Node3D

var ik: LegIK

func _ready() -> void:
	# Параметры FL из mech.gd: side=-1, поэтому abduct=-45°
	# knee и ankle — это отклонения от вертикали, в IK передаём абсолютные углы
	# В покое: abduct=-45°, pitch=15°, knee=65° (сгиб), ankle=-20° (компенсация)
	ik = LegIK.new(1.2, 1.2, -45.0, 15.0, 65.0, -20.0)
	
	# Вычисляем позицию покоя через FK
	var rest_pos := ik.forward_kinematics(
		ik.rest_hip_abduct,
		ik.rest_hip_pitch,
		ik.rest_knee,
		ik.rest_ankle
	)
	
	print("=== Проверка IK на позиции покоя ===")
	print("Позиция покоя (FK): %s" % rest_pos)
	
	var sol = ik.solve(rest_pos)
	print("Hip Abduct dev:  %.1f° (должно быть ~0°)" % rad_to_deg(sol["hip_abduct_dev"]))
	print("Hip Pitch dev:   %.1f° (должно быть ~0°)" % rad_to_deg(sol["hip_pitch_dev"]))
	print("Knee dev:        %.1f° (должно быть ~0°)" % rad_to_deg(sol["knee_dev"]))
	print("Ankle dev:       %.1f° (должно быть ~0°)" % rad_to_deg(sol["ankle_dev"]))
	
	print("\n=== Тест траектории (увеличенный размах) ===")
	# Увеличиваем размах: из задней позиции в переднюю
	# Смещение по Z: ±0.4 м (вместо ±0.2 м)
	var swing_start := rest_pos + Vector3(0, 0.15, -0.4)  # Сзади и чуть выше
	var swing_end := rest_pos + Vector3(0, 0.15, 0.4)     # Впереди и чуть выше
	
	var traj := SwingTrajectory.new(swing_start, swing_end, 0.25, 0.1)
	
	for t in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var pos = traj.get_position(t)
		var sol_t = ik.solve(pos)
		
		print("\nt=%.2f | Цель: %s" % [t, pos])
		print("  Hip Abduct dev:  %6.1f° (лимит ±50°)" % rad_to_deg(sol_t["hip_abduct_dev"]))
		print("  Hip Pitch dev:   %6.1f° (лимит ±30°)" % rad_to_deg(sol_t["hip_pitch_dev"]))
		print("  Knee dev:        %6.1f° (лимит ±50°)" % rad_to_deg(sol_t["knee_dev"]))
		print("  Ankle dev:       %6.1f° (лимит ±40°)" % rad_to_deg(sol_t["ankle_dev"]))
