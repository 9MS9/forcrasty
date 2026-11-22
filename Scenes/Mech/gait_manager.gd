extends Node3D

@export var step_trigger_distance: float = 1.0
@export var step_time_offset: float = 0.15

var legs: Array[Node3D] = []
# Порядок: FL(0), BR(3), FR(1), BL(2) - диагональная походка
var step_order: Array = [0, 3, 1, 2] 
var current_step_idx: int = 0
var step_cooldown: float = 0.0
var last_body_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	var parent = get_parent()
	legs = [
		parent.get_node("LegFL"),
		parent.get_node("LegFR"),
		parent.get_node("LegBL"),
		parent.get_node("LegBR")
	]
	last_body_position = parent.global_position

func _process(delta: float) -> void:
	if step_cooldown > 0:
		step_cooldown -= delta
	
	var current_pos: Vector3 = get_parent().global_position
	var movement: Vector3 = current_pos - last_body_position
	var speed: float = movement.length() / delta if delta > 0 else 0.0
	last_body_position = current_pos
	
	if speed > 0.1 and step_cooldown <= 0:
		var leg_index = step_order[current_step_idx]
		var leg = legs[leg_index]
		
		if leg.get("current_state") == leg.get("LegState").STANCE:
			var forward_dir: Vector3 = movement.normalized()
			
			# ВАЖНО: Цель шага считается от ПЛЕЧА, а не от ступни.
			# Это заставляет ногу ставить ступню на фиксированное расстояние впереди.
			var target: Vector3 = leg.shoulder_pivot.global_position + forward_dir * step_trigger_distance
			
			# Проверяем землю
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(target + Vector3(0, 2, 0), target + Vector3(0, -2, 0))
			var result = space_state.intersect_ray(query)
			
			if result:
				target = result.position
			
			leg.start_step(target)
			step_cooldown = step_time_offset
			current_step_idx = (current_step_idx + 1) % step_order.size()
