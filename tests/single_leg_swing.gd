extends Node3D
## АВТОМАТИЧЕСКАЯ СБОРКА И ТЕСТ ОДНОЙ НОГИ (SWING PHASE)

const JointDriverScript = preload("res://scripts/joint_driver.gd")
const AxisCfg = preload("res://resources/joint_axis_config.gd")
const FootBodyScript = preload("res://scripts/foot_body.gd")
const LegIKScript = preload("res://scripts/leg_ik.gd")
const PhaseControllerScript = preload("res://scripts/leg_phase_controller.gd")

const L_UPPER := 1.2
const L_LOWER := 1.2
const FOOT_H := 0.25

# Тест: pitch=0, чтобы стопа в покое была строго горизонтальна
const REST_ABDUCT := -45.0
const REST_PITCH := 0.0
const REST_KNEE := 65.0
const REST_ANKLE := -20.0

var _anchor: StaticBody3D
var _upper: RigidBody3D
var _lower: RigidBody3D
var _foot: FootBodyScript
var _ground: StaticBody3D

var _ik: LegIKScript
var _phase_ctrl: PhaseControllerScript
var _drivers: Array = []

func _ready() -> void:
	_build_camera_and_light()
	_build_environment()
	_build_leg()
	_setup_controllers()
	print(">>> Нажмите ПРОБЕЛ — нога переставится вперёд на 0.4 м")

func _build_camera_and_light() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(4, 2.5, 4)
	add_child(cam)  # ← СНАЧАЛА добавляем
	cam.look_at(Vector3(0, 1.2, 0))  # ← ПОТОМ вызываем look_at
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)

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
	sh.size = Vector3(10, 0.5, 10)
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

func _build_leg() -> void:
	_ik = LegIKScript.new(L_UPPER, L_LOWER, REST_ABDUCT, REST_PITCH, REST_KNEE, REST_ANKLE)
	# Позиция стопы относительно бедра в покое
	var foot_off := _ik.forward_kinematics(
		deg_to_rad(REST_ABDUCT), deg_to_rad(REST_PITCH), deg_to_rad(REST_KNEE), deg_to_rad(REST_ANKLE))
	# Ставим бедро так, чтобы центр стопы был на FOOT_H*0.5 (низ стопы = Y=0)
	var hip_pos := Vector3(-foot_off.x, FOOT_H * 0.5 - foot_off.y, -foot_off.z)

	_anchor = StaticBody3D.new()
	_anchor.name = "Anchor"
	_anchor.collision_layer = 2
	_anchor.collision_mask = 0
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(0.5, 0.5, 0.5)
	acs.shape = ash
	_anchor.add_child(acs)
	_anchor.position = hip_pos
	add_child(_anchor)

	_upper = _box_body(Vector3(0.3, L_UPPER, 0.4), 400.0, 2, 1)
	_upper.name = "UpperLeg"
	_lower = _box_body(Vector3(0.25, L_LOWER, 0.3), 250.0, 2, 1)
	_lower.name = "LowerLeg"
	_foot = FootBodyScript.new()
	_foot.name = "Foot"
	_foot.mass = 100.0
	_foot.collision_layer = 2
	_foot.collision_mask = 1
	_foot.can_sleep = false
	_foot.contact_monitor = true
	_foot.max_contacts_reported = 4
	_foot.physics_material_override = _mat(0.8)
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(0.5, FOOT_H, 0.5)
	fcs.shape = fsh
	_foot.add_child(fcs)
	var fmi := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = fsh.size
	fmi.mesh = fbm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.62, 0.53, 0.36)
	fmi.material_override = fmat
	_foot.add_child(fmi)

	var b_hip := Basis(Vector3(0, 0, 1), deg_to_rad(REST_ABDUCT)) * Basis(Vector3(1, 0, 0), deg_to_rad(REST_PITCH))
	var knee_pos := hip_pos + b_hip * Vector3(0, -L_UPPER, 0)
	var b_knee := b_hip * Basis(Vector3(0, 0, 1), deg_to_rad(REST_KNEE))
	var ankle_pos := knee_pos + b_knee * Vector3(0, -L_LOWER, 0)
	var b_foot := b_knee * Basis(Vector3(0, 0, 1), deg_to_rad(REST_ANKLE))
	var foot_pos := ankle_pos + b_foot * Vector3(0, -FOOT_H * 0.5, 0)

	_upper.position = hip_pos + b_hip * Vector3(0, -L_UPPER * 0.5, 0)
	_upper.basis = b_hip
	_lower.position = knee_pos + b_knee * Vector3(0, -L_LOWER * 0.5, 0)
	_lower.basis = b_knee
	_foot.position = foot_pos
	_foot.basis = b_foot
	add_child(_upper)
	add_child(_lower)
	add_child(_foot)

	_make_joint(_anchor, _upper, hip_pos, [0, 2], [[-30.0, 30.0], [-50.0, 50.0]], [80000.0, 80000.0])
	_make_joint(_upper, _lower, knee_pos, [2], [[-50.0, 50.0]], [80000.0])
	_make_joint(_lower, _foot, ankle_pos, [2], [[-40.0, 40.0]], [20000.0])
	_hip_basis = b_hip
	_hip_origin = hip_pos

var _hip_basis: Basis
var _hip_origin: Vector3

func _make_joint(a: PhysicsBody3D, b: PhysicsBody3D, pos: Vector3, axes: Array, limits: Array, torques: Array) -> void:
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
		c.lower_deg = limits[i][0]
		c.upper_deg = limits[i][1]
		c.max_torque = torques[i]
		c.stiffness = 80000.0
		c.damping_ratio = 2.0
		c.target_deg = 0.0
		cfg_arr.append(c)
	drv.axes = ax_arr
	drv.configs = cfg_arr
	j.add_child(drv)
	_drivers.append(drv)

func _setup_controllers() -> void:
	# Теперь передаём только драйверы и стопу, IK больше не нужен для этого теста
	_phase_ctrl = PhaseControllerScript.new(_drivers, _foot)

func _physics_process(delta: float) -> void:
	if not _phase_ctrl:
		return
	_phase_ctrl.update(delta)
	_phase_ctrl.check_foot_contact()

	if Input.is_action_just_pressed("ui_accept"):
		if _phase_ctrl.phase == PhaseControllerScript.Phase.STANCE:
			_phase_ctrl.start_swing()

	if is_instance_valid(_foot):
		DebugDraw3D.draw_sphere(_foot.global_position, 0.08, Color.RED, 0)
		for i in _foot.points.size():
			DebugDraw3D.draw_sphere(_foot.points[i], 0.05, Color.GREEN, 0)
			DebugDraw3D.draw_line(_foot.points[i], _foot.points[i] + _foot.normals[i] * 0.5, Color.CYAN, 0)

	DebugDraw2D.set_text("Phase", "SWING" if _phase_ctrl.phase == PhaseControllerScript.Phase.SWING else "STANCE")
	DebugDraw2D.set_text("k_scale", "%.2f" % _phase_ctrl.k_scale_current)
	DebugDraw2D.set_text("Foot Stance", "YES" if _foot.stance else "NO")
	if _drivers.size() >= 3:
		var hip_ang: Array[float] = _drivers[0].angles_deg()
		var hip_targ: Array[float] = _drivers[0].targets_deg()
		var knee_ang: Array[float] = _drivers[1].angles_deg()
		var ankle_ang: Array[float] = _drivers[2].angles_deg()
		
		DebugDraw2D.set_text("Hip Pitch", "fact %.1f° | targ %.1f°" % [hip_ang[0], hip_targ[0]])
		DebugDraw2D.set_text("Hip Abduct", "fact %.1f° | targ %.1f°" % [hip_ang[1], hip_targ[1]])
		DebugDraw2D.set_text("Knee", "fact %.1f° | targ %.1f°" % [knee_ang[0], _drivers[1].targets_deg()[0]])
		DebugDraw2D.set_text("Ankle", "fact %.1f° | targ %.1f°" % [ankle_ang[0], _drivers[2].targets_deg()[0]])
