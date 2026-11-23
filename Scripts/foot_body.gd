class_name FootBody
extends RigidBody3D

@export var min_normal_dot: float = 0.766

var stance: bool = false
var points: Array[Vector3] = []
var normals: Array[Vector3] = []
var load_n: float = 0.0
var _hits: int = 0
var _miss: int = 0

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	points.clear()
	normals.clear()
	var impulse_sum := 0.0
	var xf := state.transform  # АКТУАЛЬНЫЙ трансформ тела в физшаге (не устаревший узловой)
	var up := Vector3.UP
	for i in state.get_contact_count():
		var n := xf.basis * state.get_contact_local_normal(i)
		if n.dot(up) < 0.0:
			n = -n
		if n.dot(up) < min_normal_dot:
			continue
		var p := xf.origin + xf.basis * state.get_contact_local_position(i)
		if p.distance_to(xf.origin) > 0.8:
			continue  # санитизация: контакт не может быть дальше стопы
		points.append(p)
		normals.append(n)
		impulse_sum += state.get_contact_impulse(i).length()
	load_n = impulse_sum / state.step
	if points.size() > 0:
		_hits += 1
		_miss = 0
	else:
		_miss += 1
		_hits = 0
	if _hits >= 3:
		stance = true
	elif _miss >= 4:
		stance = false
