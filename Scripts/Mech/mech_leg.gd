extends Node3D
class_name MechLeg

enum LegState { STANCE, SWING }

@export_group("IK Settings")
@export var upper_leg_length: float = 1.0
@export var lower_leg_length: float = 1.0
## +1: колено гнётся назад (как у собаки/птицы), -1: вперёд (как у человека)
@export_range(-1, 1, 2) var knee_bend_sign: int = 1
## Насколько далеко ступня стоит от проекции плеча в покое (наружу от корпуса)
@export var foot_spread: float = 0.3

@export_group("Step Settings")
@export var step_height: float = 0.4
@export var step_duration: float = 0.3
@export var raycast_length: float = 3.0

var current_state: LegState = LegState.STANCE
## МИРОВАЯ точка опоры. В STANCE она НЕПОДВИЖНА — это якорь, который толкает корпус.
var planted_position: Vector3 = Vector3.ZERO
var ground_normal: Vector3 = Vector3.UP
var is_grounded: bool = false

var target_position: Vector3 = Vector3.ZERO
var step_timer: float = 0.0
var step_start_pos: Vector3 = Vector3.ZERO
var step_target_pos: Vector3 = Vector3.ZERO

var initial_shoulder_rotation: Vector3
var _rest_offset: Vector3 = Vector3.ZERO   # локальное смещение ступни в покое

@onready var shoulder_pivot: Node3D = $ShoulderPivot
@onready var knee_pivot: Node3D = $ShoulderPivot/UpperLeg/KneePivot
@onready var foot_pivot: Node3D = $ShoulderPivot/UpperLeg/KneePivot/LowerLeg/FootPivot
@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	initial_shoulder_rotation = shoulder_pivot.rotation
	# Запоминаем "домашнюю" позицию ступни относительно плеча (задана в редакторе)
	_rest_offset = shoulder_pivot.to_local(foot_pivot.global_position)
	_rest_offset.x = sign(_rest_offset.x) * max(abs(_rest_offset.x), foot_spread)

	raycast.enabled = true
	raycast.target_position = Vector3(0, -raycast_length, 0)
	raycast.force_raycast_update()
	if raycast.is_colliding():
		planted_position = raycast.get_collision_point()
		ground_normal = raycast.get_collision_normal()
		is_grounded = true
	else:
		planted_position = foot_pivot.global_position
	target_position = planted_position

## Точка, где ступня ДОЛЖНА стоять при текущей позе корпуса (для проверки отставания)
func get_desired_plant() -> Vector3:
	var desired: Vector3 = shoulder_pivot.global_position + shoulder_pivot.global_transform.basis * _rest_offset
	# Лучим вниз из желаемой точки, чтобы найти землю
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		desired + Vector3.UP * 1.0,
		desired + Vector3.DOWN * raycast_length)
	query.exclude = [get_parent().get_rid()] if get_parent() is CollisionObject3D else []
	var hit := space.intersect_ray(query)
	if hit:
		return hit.position
	return desired

func start_step(new_target: Vector3) -> void:
	if current_state == LegState.SWING:
		return
	current_state = LegState.SWING
	is_grounded = false          # нога в воздухе — не опора, не толкает
	step_timer = 0.0
	step_start_pos = planted_position
	step_target_pos = new_target

func update_leg(delta: float) -> void:
	if current_state == LegState.SWING:
		step_timer += delta
		var t: float = clamp(step_timer / step_duration, 0.0, 1.0)
		# smoothstep по горизонтали + дуга по высоте
		var s: float = t * t * (3.0 - 2.0 * t)
		target_position = step_start_pos.lerp(step_target_pos, s) \
			+ Vector3.UP * sin(t * PI) * step_height
		if t >= 1.0:
			current_state = LegState.STANCE
			planted_position = step_target_pos   # новый якорь зафиксирован в мире
			is_grounded = true
			target_position = planted_position
	else:
		# STANCE: цель = неподвижная мировая точка. Корпус уезжает — нога остаётся.
		target_position = planted_position
	solve_ik()

func solve_ik() -> void:
	# 1. Сброс к исходной ориентации (никакого накопления ошибки)
	shoulder_pivot.rotation = initial_shoulder_rotation
	knee_pivot.rotation = Vector3.ZERO

	# 2. Цель в локальных координатах плеча
	var local_target: Vector3 = shoulder_pivot.to_local(target_position)
	var raw_distance: float = local_target.length()
	if raw_distance < 0.0001:
		return
	var dir: Vector3 = local_target / raw_distance

	# 3. Ограничение досягаемости
	var max_reach: float = (upper_leg_length + lower_leg_length) * 0.999
	var min_reach: float = abs(upper_leg_length - lower_leg_length) + 0.01
	var distance: float = clamp(raw_distance, min_reach, max_reach)

	# 4. Закон косинусов
	var cos_knee: float = (upper_leg_length ** 2 + lower_leg_length ** 2 - distance ** 2) \
		/ (2.0 * upper_leg_length * lower_leg_length)
	var knee_inner: float = acos(clamp(cos_knee, -1.0, 1.0))
	var knee_bend: float = PI - knee_inner          # 0 = прямая нога

	var cos_shoulder: float = (upper_leg_length ** 2 + distance ** 2 - lower_leg_length ** 2) \
		/ (2.0 * upper_leg_length * distance)
	var shoulder_angle: float = acos(clamp(cos_shoulder, -1.0, 1.0))

	# 5. НАВЕДЕНИЕ — углы от оси -Y (вниз), а НЕ от горизонта!
	# Yaw: разворачиваем плоскость сгиба колена к цели
	var yaw: float = atan2(dir.x, dir.z)
	# Tilt: угол ОТКЛОНЕНИЯ ОТ ВЕРТИКАЛИ. Цель прямо внизу -> tilt = 0 -> нога вертикальна.
	var tilt: float = atan2(sqrt(dir.x * dir.x + dir.z * dir.z), -dir.y)
	# Наклон бедра: недокручиваем до цели на shoulder_angle (остальное добирает колено)
	var pitch: float = -(tilt - shoulder_angle) * knee_bend_sign

	shoulder_pivot.rotate_object_local(Vector3.UP, yaw)
	shoulder_pivot.rotate_object_local(Vector3.RIGHT, pitch)

	# 6. Колено добирает оставшийся угол (знак противоположен наклону бедра)
	knee_pivot.rotation = Vector3(-knee_bend * knee_bend_sign, 0, 0)

	# 7. Ступня: компенсируем суммарный наклон цепи, оставляя развал плеча и yaw.
	# Это НЕ global_rotation = ZERO (циклической зависимости нет — считаем из известных углов).
	foot_pivot.rotation = Vector3(-(pitch - knee_bend * knee_bend_sign), 0, 0)
