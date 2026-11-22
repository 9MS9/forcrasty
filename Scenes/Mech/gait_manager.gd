extends Node3D

@export var step_trigger_distance: float = 0.6
## Насколько агрессивно отставшие якоря тянут корпус вперёд
@export var propulsion_gain: float = 6.0
@export var step_time_offset: float = 0.12
## Минимум опорных ног на земле, чтобы корпус вообще мог двигаться
@export var min_support_legs: int = 2

var legs: Array = []
var diagonal_pairs: Array = [[0, 3], [1, 2]]   # FL+BR, затем FR+BL
var current_pair_idx: int = 0
var step_cooldown: float = 0.0

## Желаемая скорость от контроллера движения (задаётся каждый кадр)
var desired_velocity: Vector3 = Vector3.ZERO
## Итоговая скорость, которую должен применить mech_movement
var computed_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	var parent := get_parent()
	legs = [
		parent.get_node("LegFL"),
		parent.get_node("LegFR"),
		parent.get_node("LegBL"),
		parent.get_node("LegBR"),
	]

func _physics_process(delta: float) -> void:
	step_cooldown = max(step_cooldown - delta, 0.0)

	# --- 1. Планирование шагов: пара шагает, когда её якоря отстали ---
	var speed: float = desired_velocity.length()
	if speed > 0.05 and step_cooldown <= 0.0:
		var pair: Array = diagonal_pairs[current_pair_idx]
		var a = legs[pair[0]]
		var b = legs[pair[1]]
		var other: Array = diagonal_pairs[(current_pair_idx + 1) % 2]
		# Вторая пара должна стоять на земле (диагональная походка)
		var other_grounded: bool = legs[other[0]].is_grounded and legs[other[1]].is_grounded
		if other_grounded and a.current_state == a.LegState.STANCE and b.current_state == b.LegState.STANCE:
			var lag_a: float = a.planted_position.distance_to(a.get_desired_plant())
			var lag_b: float = b.planted_position.distance_to(b.get_desired_plant())
			if max(lag_a, lag_b) > step_trigger_distance:
				_start_pair_step(pair)
				step_cooldown = step_time_offset
				current_pair_idx = (current_pair_idx + 1) % diagonal_pairs.size()

	# --- 2. ДВИЖЕНИЕ ИЗ ОПОР: корпус толкают отставшие якоря ---
	var anchor_error := Vector3.ZERO
	var support_count: int = 0
	for leg in legs:
		if leg.is_grounded and leg.current_state == leg.LegState.STANCE:
			support_count += 1
			# Вектор от текущего якоря к "домашней" точке: куда нога тянет корпус
			var pull: Vector3 = leg.get_desired_plant() - leg.planted_position
			pull.y = 0.0
			anchor_error += pull
	if support_count > 0:
		anchor_error /= float(support_count)

	if support_count >= min_support_legs:
		# Скорость = команда игрока + коррекция отставания якорей.
		# Ноги физически "догоняют" своё положение под корпусом -> корпус едет.
		computed_velocity = desired_velocity + anchor_error * propulsion_gain
		# Не даём разогнаться сильнее команды (якоря только передают усилие, не разгоняют сверх меры)
		var max_speed: float = desired_velocity.length() * 1.2 + 0.1
		if computed_velocity.length() > max_speed:
			computed_velocity = computed_velocity.normalized() * max_speed
	else:
		# Нет опоры — нет тяги. Мех не скользит в воздухе.
		computed_velocity = Vector3.ZERO

	# --- 3. Обновление ног (stance держит якорь, swing летит по дуге) ---
	for leg in legs:
		leg.update_leg(delta)

func _start_pair_step(pair: Array) -> void:
	var body := get_parent() as Node3D
	var dir: Vector3 = desired_velocity.normalized()
	var speed: float = desired_velocity.length()
	for idx in pair:
		var leg = legs[idx]
		# Упреждение: ступня целится туда, где будет плечо к концу шага
		var lead: Vector3 = desired_velocity * leg.step_duration * 0.5
		var target: Vector3 = leg.get_desired_plant() + lead
		# Проверка земли рейкастом
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			target + Vector3.UP * 2.0, target + Vector3.DOWN * 4.0)
		if body is CollisionObject3D:
			query.exclude = [body.get_rid()]
		var hit := space.intersect_ray(query)
		if hit:
			target = hit.position
		leg.start_step(target)
