class_name JointDriver
extends Node

const AxisCfg = preload("res://resources/joint_axis_config.gd")

@export var configs: Array[AxisCfg] = []
@export var axes: Array[int] = [0]

var joint: Generic6DOFJoint3D
var body_a: PhysicsBody3D   # ТЕПЕРЬ PhysicsBody3D: поддерживает StaticBody-якорь
var body_b: PhysicsBody3D
var enabled: bool = true
var k_scale: float = 1.0

var _rest_rel: Basis
var _targets: Array[float] = []
var _angles: Array[float] = []
var _torques: Array[float] = []
var _suffix := ["x", "y", "z"]

func _ready() -> void:
	joint = get_parent() as Generic6DOFJoint3D
	body_a = joint.get_node(joint.node_a) as PhysicsBody3D
	body_b = joint.get_node(joint.node_b) as PhysicsBody3D
	if body_a == null or body_b == null:
		push_error("JointDriver: тела не найдены node_a='%s' node_b='%s'" % [joint.node_a, joint.node_b])
		return
	_rest_rel = body_a.global_basis.inverse() * body_b.global_basis
	for i in configs.size():
		_targets.append(deg_to_rad(configs[i].target_deg))
		_angles.append(0.0)
		_torques.append(0.0)
	for _s in _suffix:
		joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
	for axis in 3:
		var idx := axes.find(axis)
		var _s: String = _suffix[axis]
		joint.call("set_flag_" + _s, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		if idx == -1:
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
		else:
			var c: AxisCfg = configs[idx]
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(c.lower_deg))
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(c.upper_deg))

func _ang_vel(b: PhysicsBody3D) -> Vector3:
	return b.angular_velocity if b is RigidBody3D else Vector3.ZERO

func _physics_process(delta: float) -> void:
	if body_a == null or body_b == null or not enabled:
		return
	var rel := (body_a.global_basis.inverse() * body_b.global_basis) * _rest_rel.inverse()
	var euler := rel.get_euler()
	var w_a := _ang_vel(body_a)
	var w_b := _ang_vel(body_b)
	for i in configs.size():
		var c: AxisCfg = configs[i]
		var axis := axes[i]
		_angles[i] = euler[axis]
		var goal := deg_to_rad(c.target_deg)
		_targets[i] = move_toward(_targets[i], goal, deg_to_rad(c.slew_rate_deg) * delta)
		var err := _targets[i] - _angles[i]
		var axis_world := body_a.global_basis[axis]
		var w := (w_b - w_a).dot(axis_world)

		var tmax := c.max_torque * c.damage_scale
		var k := c.stiffness * k_scale * (0.3 + 0.7 * c.damage_scale)

		var I: float = 0.5
		if body_b is RigidBody3D:
			var axis_local := body_b.global_basis.inverse() * axis_world
			var I_axis: float = body_b.inertia.x * axis_local.x * axis_local.x \
				+ body_b.inertia.y * axis_local.y * axis_local.y \
				+ body_b.inertia.z * axis_local.z * axis_local.z
			I = maxf(I_axis, 0.5)

		var w_max := 4.0 / delta
		k = minf(k, w_max * w_max * I)

		var damp: float = 2.0 * c.damping_ratio * sqrt(k * I)
		var t := k * err - damp * w
		t = clampf(t, -tmax, tmax)

		var max_step := tmax * c.torque_slew
		t = clampf(t, _torques[i] - max_step, _torques[i] + max_step)
		_torques[i] = t

		if body_b is RigidBody3D:
			body_b.apply_torque(axis_world * t)
		if body_a is RigidBody3D:
			body_a.apply_torque(axis_world * -t)

func angles_deg() -> Array[float]:
	var out: Array[float] = []
	for a in _angles: out.append(rad_to_deg(a))
	return out

func targets_deg() -> Array[float]:
	var out: Array[float] = []
	for t in _targets: out.append(rad_to_deg(t))
	return out

func torques() -> Array[float]:
	return _torques
