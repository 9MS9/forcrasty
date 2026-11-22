extends Node3D

enum LegState { STANCE, SWING }

@export_group("IK Settings")
@export var upper_leg_length: float = 1.0
@export var lower_leg_length: float = 1.0

@export_group("Step Settings")
@export var step_height: float = 0.4
@export var step_duration: float = 0.3

var target_position: Vector3 = Vector3.ZERO
var current_state: LegState = LegState.STANCE
var step_timer: float = 0.0
var step_start_pos: Vector3 = Vector3.ZERO
var step_target_pos: Vector3 = Vector3.ZERO

# Сохраняем изначальный поворот плеча
var initial_shoulder_quat: Quaternion

@onready var shoulder_pivot: Node3D = $ShoulderPivot
@onready var knee_pivot: Node3D = $ShoulderPivot/UpperLeg/KneePivot
@onready var foot_pivot: Node3D = $ShoulderPivot/UpperLeg/KneePivot/LowerLeg/FootPivot
@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	initial_shoulder_quat = shoulder_pivot.quaternion
	
	raycast.force_raycast_update()
	if raycast.is_colliding():
		target_position = raycast.get_collision_point()
	else:
		target_position = foot_pivot.global_position

func _process(delta: float) -> void:
	if current_state == LegState.SWING:
		step_timer += delta
		var t: float = clamp(step_timer / step_duration, 0.0, 1.0)
		
		var horizontal_pos: Vector3 = step_start_pos.lerp(step_target_pos, t)
		var height_offset: float = sin(t * PI) * step_height
		target_position = horizontal_pos + Vector3(0, height_offset, 0)
		
		if t >= 1.0:
			current_state = LegState.STANCE
			step_timer = 0.0
			target_position = step_target_pos
	else:
		raycast.force_raycast_update()
		if raycast.is_colliding():
			target_position = raycast.get_collision_point()
	
	solve_ik()

func start_step(new_target: Vector3) -> void:
	if current_state == LegState.SWING:
		return
	current_state = LegState.SWING
	step_timer = 0.0
	step_start_pos = foot_pivot.global_position
	step_target_pos = new_target

func solve_ik() -> void:
	if not shoulder_pivot or not knee_pivot or not foot_pivot:
		return
		
	var shoulder_global_pos: Vector3 = shoulder_pivot.global_position
	var to_target: Vector3 = target_position - shoulder_global_pos
	var distance: float = to_target.length()
	
	var max_reach: float = upper_leg_length + lower_leg_length
	var min_reach: float = abs(upper_leg_length - lower_leg_length) + 0.01
	distance = clamp(distance, min_reach, max_reach)
	
	# Закон косинусов
	var cos_knee: float = (upper_leg_length * upper_leg_length + lower_leg_length * lower_leg_length - distance * distance) / (2.0 * upper_leg_length * lower_leg_length)
	cos_knee = clamp(cos_knee, -1.0, 1.0)
	var knee_angle: float = acos(cos_knee)
	
	var cos_shoulder: float = (upper_leg_length * upper_leg_length + distance * distance - lower_leg_length * lower_leg_length) / (2.0 * upper_leg_length * distance)
	cos_shoulder = clamp(cos_shoulder, -1.0, 1.0)
	var shoulder_angle: float = acos(cos_shoulder)
	
	# --- МАТЕМАТИКА IK ---
	# 1. Вектор до цели в локальных координатах ноги
	var local_target: Vector3 = to_local(target_position)
	var local_shoulder_pos: Vector3 = shoulder_pivot.position
	var target_dir: Vector3 = (local_target - local_shoulder_pos).normalized()
	
	# 2. Вектор "вниз" (в покое нога смотрит вниз)
	var down_dir := Vector3.DOWN
	
	# 3. Вычисляем ось и угол поворота от "вниз" к цели
	var rot_axis: Vector3 = down_dir.cross(target_dir).normalized()
	if rot_axis.length() < 0.001:
		rot_axis = Vector3.RIGHT
		
	var rot_angle: float = down_dir.angle_to(target_dir)
	
	# 4. Создаем кватернион наведения на цель
	var aim_quat := Quaternion(rot_axis, rot_angle)
	
	# 5. Создаем кватернион сгиба плеча (отводим бедро назад, чтобы колено согнулось)
	# Если колено выгибается вперед, меняем знак на минус
	var bend_quat := Quaternion(Vector3.RIGHT, shoulder_angle)
	
	# 6. Применяем: изначальный поворот * наведение * сгиб
	shoulder_pivot.quaternion = initial_shoulder_quat * aim_quat * bend_quat
	
	# 7. Сгибаем колено (отрицательный угол, чтобы сгибать назад)
	knee_pivot.rotation.x = -knee_angle
