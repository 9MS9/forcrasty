extends CharacterBody3D

@export_group("Movement")
@export var max_speed: float = 4.0
@export var acceleration: float = 8.0
@export var turn_speed: float = 1.2
@export var turn_acceleration: float = 3.0

@onready var gait_manager = $GaitManager

var current_turn: float = 0.0
var _commanded_velocity: Vector3 = Vector3.ZERO

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"))
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# Поворот корпуса
	var turn_input := Input.get_axis("turn_right", "turn_left")
	current_turn = move_toward(current_turn, turn_input * turn_speed, turn_acceleration * delta)
	rotate_y(current_turn * delta)

	# Это лишь ЖЕЛАНИЕ двигаться, а не само движение
	var wish: Vector3 = global_transform.basis * Vector3(input_dir.x, 0, -input_dir.y) * max_speed
	_commanded_velocity = _commanded_velocity.move_toward(wish, acceleration * delta)
	gait_manager.desired_velocity = _commanded_velocity

	# РЕАЛЬНОЕ движение даёт походка: сколько опорные ноги толкнули — столько и едем
	velocity.x = gait_manager.computed_velocity.x
	velocity.z = gait_manager.computed_velocity.z
	velocity.y = 0.0  # гравитацию вернёте на этапе стабилизации
	move_and_slide()
