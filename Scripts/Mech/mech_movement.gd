extends CharacterBody3D

@export_group("Movement")
@export var max_speed: float = 5.0
@export var acceleration: float = 3.0
@export var deceleration: float = 6.0
@export var turn_speed: float = 1.5
@export var turn_acceleration: float = 4.0
@export var gravity: float = 9.8

var current_velocity: Vector3 = Vector3.ZERO
var current_turn: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Ввод WASD
	var input_dir := Vector2.ZERO
	# ВНИМАНИЕ: Инвертируем ось X, так как у тебя A/D были перепутаны
	input_dir.x = -Input.get_axis("move_left", "move_right") 
	input_dir.y = Input.get_axis("move_forward", "move_back")
	
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	
	var target_local_velocity := Vector3(input_dir.x * max_speed, 0.0, -input_dir.y * max_speed)
	
	var local_velocity := global_transform.basis.inverse() * current_velocity
	local_velocity.x = move_toward(local_velocity.x, target_local_velocity.x, acceleration * delta)
	local_velocity.z = move_toward(local_velocity.z, target_local_velocity.z, acceleration * delta)
	
	var turn_input := Input.get_axis("turn_right", "turn_left")
	var target_turn := turn_input * turn_speed
	current_turn = move_toward(current_turn, target_turn, turn_acceleration * delta)
	rotate_y(current_turn * delta)
	
	current_velocity = global_transform.basis * local_velocity
	current_velocity.y = velocity.y
	
	velocity = current_velocity
	move_and_slide()
