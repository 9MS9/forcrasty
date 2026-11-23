extends Node3D
## Полный мех с фазовыми контроллерами ног (этап 2.2a, рефакторинг).

const JointDriverScript = preload("res://scripts/joint_driver.gd")
const AxisCfg = preload("res://resources/joint_axis_config.gd")
const FootBodyScript = preload("res://scripts/foot_body.gd")
const LegPhaseControllerScript = preload("res://scripts/leg_phase_controller.gd")

const HULL_SIZE := Vector3(3.2, 1.0, 2.0)
const HULL_MASS := 4000.0

const L_UPPER := 1.2
const L_LOWER := 1.2
const FOOT_H := 0.25

const REST_HIP_PITCH := 15.0
const REST_HIP_ABDUCT := 45.0
const REST_SHIN_INWARD := 20.0

const LEG_ATTACHMENTS := [
	Vector3(-1.4, -0.3, -1.0),  # FL
	Vector3(1.4, -0.3, -1.0),   # FR
	Vector3(-1.4, -0.3, 1.0),   # RL
	Vector3(1.4, -0.3, 1.0),    # RR
]

var _hull: RigidBody3D
var _turret: RigidBody3D
var _drivers: Array[JointDriverScript] = []
var _feet: Array[FootBodyScript] = []
var _leg_controllers: Array[LegPhaseControllerScript] = []
var _ground: StaticBody3D
var _damaged := false
var _friction_on := true

func _ready() -> void:
	_add_actions()
	_build_environment()
	_build_hull()
	_build_turret()
	for i in 4:
		_build_leg(i)
	_show_keys()

func _add_actions() -> void:
	var keys := {
		"mech_step": KEY_F1, "mech_impulse": KEY_F2,
		"mech_damage": KEY_F3, "mech_friction": KEY_F4,
		"mech_drives": KEY_F5,
	}
	for action_name in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action_name]
			InputMap.action_add_event(action_name, ev)

func _mat(friction: float) -> PhysicsMaterial:
	var m := PhysicsMaterial.new()
	m.friction = friction
	m.rough = true
	m.bounce = 0.0
	return m

func _box_body(size: Vector3, mass: float, layer: int, mask: int) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.collision_layer = layer
	b.collision_mask = mask
	b.can_sleep = false
	b.contact_monitor = true
	b.max_contacts_reported = 4
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.53, 0.36)
	mi.material_override = mat
	mi.mesh = bm
	b.add_child(mi)
	return b

func _build_environment() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "Ground"
	_ground.collision_layer = 1
	_ground.collision_mask = 0
	_ground.physics_material_override = _mat(0.8)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(40, 0.5, 40)
	cs.shape = sh
	_ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.35, 0.33)
	mi.material_override = mat
	mi.mesh = bm
	_ground.add_child(mi)
	_ground.position = Vector3(0, -0.25, 0)
	add_child(_ground)

func _build_hull() -> void:
	_hull = RigidBody3D.new()
	_hull.name = "Hull"
	_hull.mass = HULL_MASS
	_hull.collision_layer = 2
	_hull.collision_mask = 1
	_hull.can_sleep = false
	_hull.contact_monitor = true
	_hull.max_contacts_reported = 8
	_hull.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_hull.center_of_mass = Vector3(0, -0.35, 0)
	
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = HULL_SIZE
	cs.shape = sh
	_hull.add_child(cs)
	
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = HULL_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.48, 0.32)
	mi.material_override = mat
	mi.mesh = bm
	_hull.add_child(mi)
	
	_hull.position = Vector3(0, 2.52, 0)
	add_child(_hull)

func _build_turret() -> void:
	_turret = RigidBody3D.new()
	_turret.name = "Turret"
	_turret.mass = 400.0
	_turret.collision_layer = 2
	_turret.collision_mask = 1
	_turret.can_sleep = false
	
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 0.4, 0.8)
	cs.shape = sh
	_turret.add_child(cs)
	
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sh.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.40, 0.28)
	mi.material_override = mat
	mi.mesh = bm
	_turret.add_child(mi)
	
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.height = 1.8
	barrel_mesh.top_radius = 0.06
	barrel_mesh.bottom_radius = 0.08
	barrel.mesh = barrel_mesh
	barrel.material_override = mat
	barrel.position = Vector3(0, 0, -1.0)
	barrel.rotation.x = PI / 2
	_turret.add_child(barrel)
	
	_turret.position = _hull.position + Vector3(0, 0.6, 0.0)
	add_child(_turret)
	
	var joint := Generic6DOFJoint3D.new()
	joint.name = "TurretJoint"
	joint.node_a = NodePath("../Hull")
	joint.node_b = NodePath("../Turret")
	joint.position = _turret.position
	add_child(joint)
	
	for _s in ["x", "y", "z"]:
		joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, 0.0)
		joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.0)
		joint.call("set_flag_" + _s, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		if _s != "y":
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, 0.0)
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.0)
		else:
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, deg_to_rad(-115.0))
			joint.call("set_param_" + _s, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, deg_to_rad(115.0))
	
	var drv := JointDriverScript.new()
	var cfg := AxisCfg.new()
	cfg.drive_mode = AxisCfg.DriveMode.CUSTOM_PD
	cfg.stiffness = 60000.0
	cfg.damping_ratio = 1.0
	cfg.max_torque = 80000.0
	cfg.target_deg = 0.0
	drv.configs = [cfg]
	drv.axes = [1]
	joint.add_child(drv)
	_drivers.append(drv)

func _build_leg(leg_idx: int) -> void:
	var attach: Vector3 = LEG_ATTACHMENTS[leg_idx]
	var hip_pos: Vector3 = _hull.position + attach
	var side: float = 1.0 if attach.x > 0 else -1.0
	var is_front: bool = attach.z < 0
	
	var pitch: float = REST_HIP_PITCH if is_front else -REST_HIP_PITCH
	var abduct: float = REST_HIP_ABDUCT * side
	var shin: float = REST_SHIN_INWARD * side
	var knee_dev: float = -(REST_HIP_ABDUCT + REST_SHIN_INWARD) * side
	
	var b_hip := Basis(Vector3(0, 0, 1), deg_to_rad(abduct)) * Basis(Vector3(1, 0, 0), deg_to_rad(pitch))
	var p_knee := b_hip * Vector3(0, -L_UPPER, 0)
	var b_knee := b_hip * Basis(Vector3(0, 0, 1), deg_to_rad(knee_dev))
	var p_ankle := p_knee + b_knee * Vector3(0, -L_LOWER, 0)
	var b_foot := b_knee * Basis(Vector3(0, 0, 1), deg_to_rad(shin))
	var p_foot_center := p_ankle + b_foot * Vector3(0, -FOOT_H * 0.5, 0)
	
	var knee_pos: Vector3 = hip_pos + p_knee
	var ankle_pos: Vector3 = hip_pos + p_ankle
	var foot_pos: Vector3 = hip_pos + p_foot_center
	
	var upper := _box_body(Vector3(0.3, L_UPPER, 0.4), 400.0, 2, 1)
	upper.name = "UpperLeg%d" % leg_idx
	var lower := _box_body(Vector3(0.25, L_LOWER, 0.3), 250.0, 2, 1)
	lower.name = "LowerLeg%d" % leg_idx
	var foot := FootBodyScript.new()
	foot.name = "Foot%d" % leg_idx
	foot.mass = 100.0
	foot.collision_layer = 2
	foot.collision_mask = 1
	foot.can_sleep = false
	foot.contact_monitor = true
	foot.max_contacts_reported = 4
	foot.physics_material_override = _mat(0.8)
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(0.5, FOOT_H, 0.5)
	fcs.shape = fsh
	foot.add_child(fcs)
	var fmi := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = fsh.size
	fmi.mesh = fbm
	foot.add_child(fmi)
	
	upper.position = hip_pos + b_hip * Vector3(0, -L_UPPER * 0.5, 0)
	upper.basis = b_hip
	lower.position = knee_pos + b_knee * Vector3(0, -L_LOWER * 0.5, 0)
	lower.basis = b_knee
	foot.position = foot_pos
	foot.basis = b_foot
	add_child(upper)
	add_child(lower)
	add_child(foot)
	_feet.append(foot)
	
	_make_joint(_hull, upper, hip_pos, [0, 2], [[-30.0, 30.0], [-50.0, 40.0]], [100000.0, 80000.0])
	_make_joint(upper, lower, knee_pos, [2], [[-50.0, 50.0]], [100000.0])
	_make_joint(lower, foot, ankle_pos, [0, 2], [[-25.0, 25.0], [-40.0, 40.0]], [25000.0, 25000.0])
	
	# Создаём фазовый контроллер для этой ноги
	var leg_drivers: Array[JointDriverScript] = _drivers.slice(leg_idx * 3 + 1, leg_idx * 3 + 4)
	var ctrl := LegPhaseControllerScript.new(leg_drivers, foot)
	
	# Устанавливаем траекторию шага для каждой ноги
	# FL (0): вперёд-влево
	if leg_idx == 0:
		ctrl.swing_trajectory = {
			"hip_abduct_dev": -0.3,  # Влево
			"hip_pitch_dev": -0.5,   # Вперёд
			"knee_dev": 0.85,
			"ankle_dev": -0.35
		}
	# FR (1): вперёд-вправо
	elif leg_idx == 1:
		ctrl.swing_trajectory = {
			"hip_abduct_dev": 0.3,   # Вправо
			"hip_pitch_dev": -0.5,   # Вперёд
			"knee_dev": 0.85,
			"ankle_dev": -0.35
		}
	# RL (2): назад-влево
	elif leg_idx == 2:
		ctrl.swing_trajectory = {
			"hip_abduct_dev": -0.3,  # Влево
			"hip_pitch_dev": 0.5,    # Назад
			"knee_dev": 0.85,
			"ankle_dev": -0.35
		}
	# RR (3): назад-вправо
	elif leg_idx == 3:
		ctrl.swing_trajectory = {
			"hip_abduct_dev": 0.3,   # Вправо
			"hip_pitch_dev": 0.5,    # Назад
			"knee_dev": 0.85,
			"ankle_dev": -0.35
		}
	
	_leg_controllers.append(ctrl)

func _make_joint(a: PhysicsBody3D, b: PhysicsBody3D, pos: Vector3,
		axes: Array, limits_dev: Array, torques: Array) -> void:
	var j := Generic6DOFJoint3D.new()
	j.node_a = NodePath("../" + a.name)
	j.node_b = NodePath("../" + b.name)
	j.position = pos
	add_child(j)
	
	var drv := JointDriverScript.new()
	var ax_arr: Array[int] = []
	var cfg_arr: Array[AxisCfg] = []
	for i in axes.size():
		ax_arr.append(axes[i])
		var c := AxisCfg.new()
		c.drive_mode = AxisCfg.DriveMode.CUSTOM_PD
		c.lower_deg = limits_dev[i][0]
		c.upper_deg = limits_dev[i][1]
		c.max_torque = torques[i]
		c.stiffness = 80000.0
		c.damping_ratio = 2.5  # Увеличено для подавления тряски
		c.target_deg = 0.0
		cfg_arr.append(c)
	drv.axes = ax_arr
	drv.configs = cfg_arr
	j.add_child(drv)
	_drivers.append(drv)

func _show_keys() -> void:
	DebugDraw2D.set_text("keys", "F1 step FL | F2 impulse | F3 damage | F4 friction | F5 drives")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mech_step"):
		if _leg_controllers.size() > 0:
			print(">>> F1: шаг FL ногой")
			_leg_controllers[0].start_swing()
	if event.is_action_pressed("mech_impulse"):
		_hull.apply_impulse(Vector3(0, 1000, 5000.0), Vector3.ZERO)
	if event.is_action_pressed("mech_damage"):
		_damaged = not _damaged
		var dam_scale: float = 0.2 if _damaged else 1.0
		for d in _drivers:
			for c in d.configs:
				c.damage_scale = dam_scale
	if event.is_action_pressed("mech_friction"):
		_friction_on = not _friction_on
		_ground.physics_material_override.friction = 0.8 if _friction_on else 0.0
	if event.is_action_pressed("mech_drives"):
		for d in _drivers:
			d.enabled = not d.enabled

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_hull):
		return
	
	for ctrl in _leg_controllers:
		ctrl.update(delta)
		ctrl.check_foot_contact()
	
	for i in 4:
		var foot := _feet[i]
		DebugDraw3D.draw_sphere(foot.global_position, 0.08, Color.RED, 0)
		for j in foot.points.size():
			DebugDraw3D.draw_sphere(foot.points[j], 0.05, Color.GREEN, 0)
			DebugDraw3D.draw_line(foot.points[j], foot.points[j] + foot.normals[j] * 0.5, Color.CYAN, 0)
	
	DebugDraw2D.set_text("hull height", "%.2f m" % _hull.global_position.y)
	DebugDraw2D.set_text("hull pitch", "%.1f°" % rad_to_deg(_hull.global_basis.get_euler().x))
	DebugDraw2D.set_text("hull roll", "%.1f°" % rad_to_deg(_hull.global_basis.get_euler().z))
	DebugDraw2D.set_text("friction", "ON" if _friction_on else "ZERO")
	DebugDraw2D.set_text("damage", "ON" if _damaged else "off")
	DebugDraw2D.set_text("drives", "ON" if _drivers[0].enabled else "OFF")
	
	var total_load: float = 0.0
	var stance_count: int = 0
	for foot in _feet:
		total_load += foot.load_n
		if foot.stance:
			stance_count += 1
	DebugDraw2D.set_text("total load N", "%.0f" % total_load)
	DebugDraw2D.set_text("stance feet", "%d / 4" % stance_count)
	
	var phases: String = ""
	for i in 4:
		var ctrl := _leg_controllers[i]
		var phase_str := "S" if ctrl.phase == LegPhaseControllerScript.Phase.STANCE else "W"
		var k_str := "%.2f" % ctrl.k_scale_current
		phases += "%s:%s " % [phase_str, k_str]
	DebugDraw2D.set_text("leg phases", phases)
