extends Node3D
## Тестовый стенд 1.1a: неподвижный якорь + одна полная нога + пол + ступенька.

# ЯВНАЯ ЗАГРУЗКА СКРИПТОВ (обходит проблемы кэша class_name)
const JointDriverScript = preload("res://scripts/joint_driver.gd")
const AxisCfg = preload("res://resources/joint_axis_config.gd")
const FootBodyScript = preload("res://scripts/foot_body.gd")

const L_UPPER := 1.0
const L_LOWER := 1.0
const FOOT_H := 0.25
const REST_HIP_PITCH := 0.0
const REST_HIP_ABDUCT := 25.0
const REST_KNEE := -50.0
const REST_ANKLE_X := 50.0
const REST_ANKLE_Z := -25.0

var _drivers: Array[JointDriverScript] = []
var _foot: FootBodyScript
var _ground: StaticBody3D
var _upper: RigidBody3D
var _lower: RigidBody3D
var _hip_pos: Vector3
var _knee_pos: Vector3
var _ankle_pos: Vector3
var _friction_on := true
var _damaged := false

func _ready() -> void:
	_add_actions()
	_build_environment()
	_build_leg()
	_show_keys()

func _add_actions() -> void:
	var keys := {
		"rig_mode": KEY_F1, "rig_impulse": KEY_F2, "rig_damage": KEY_F3,
		"rig_friction": KEY_F4, "rig_drives": KEY_F5,
	}
	# ИСПРАВЛЕНО: action_name вместо name, чтобы не перекрывать свойство Node
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
	_ground.name = "Ground" # ИСПРАВЛЕНО: явное имя для пути
	_ground.collision_layer = 1
	_ground.collision_mask = 0
	_ground.physics_material_override = _mat(1.2)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(24, 0.5, 24)
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
	
	var step := StaticBody3D.new()
	step.name = "Step"
	step.collision_layer = 1
	var scs := CollisionShape3D.new()
	var ssh := BoxShape3D.new()
	ssh.size = Vector3(3, 0.35, 2)
	scs.shape = ssh
	step.add_child(scs)
	var smi := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = ssh.size
	smi.mesh = sbm
	smi.material_override = mat
	step.add_child(smi)
	step.position = Vector3(0, 0.175, -3.5)
	add_child(step)

func _build_leg() -> void:
	var b_hip := Basis(Vector3.RIGHT, deg_to_rad(REST_HIP_PITCH)) * Basis(Vector3.BACK, deg_to_rad(REST_HIP_ABDUCT))
	var p_knee := b_hip * Vector3(0, -L_UPPER, 0)
	var b_knee := b_hip * Basis(Vector3.RIGHT, deg_to_rad(REST_KNEE))
	var p_ankle := p_knee + b_knee * Vector3(0, -L_LOWER, 0)
	var b_foot := b_knee * Basis(Vector3.RIGHT, deg_to_rad(REST_ANKLE_X)) * Basis(Vector3.BACK, deg_to_rad(REST_ANKLE_Z))
	var p_foot_center := p_ankle + b_foot * Vector3(0, -FOOT_H * 0.5, 0)
	var bottom := p_foot_center.y - FOOT_H * 0.5
	var anchor_y := -bottom - 0.02
	_hip_pos = Vector3(0, anchor_y, 0)
	_knee_pos = _hip_pos + p_knee
	_ankle_pos = _hip_pos + p_ankle

	var anchor := StaticBody3D.new()
	anchor.name = "Anchor" # ИСПРАВЛЕНО: явное имя
	anchor.collision_layer = 2
	anchor.collision_mask = 0
	var acs := CollisionShape3D.new()
	var ash := BoxShape3D.new()
	ash.size = Vector3(0.6, 0.4, 0.6)
	acs.shape = ash
	anchor.add_child(acs)
	anchor.position = _hip_pos
	add_child(anchor)

	_upper = _box_body(Vector3(0.35, L_UPPER, 0.45), 550.0, 2, 1)
	_upper.name = "UpperLeg" # ИСПРАВЛЕНО: явное имя
	_lower = _box_body(Vector3(0.28, L_LOWER, 0.35), 320.0, 2, 1)
	_lower.name = "LowerLeg" # ИСПРАВЛЕНО: явное имя
	_foot = FootBodyScript.new() # ИСПРАВЛЕНО: использование preload типа
	_foot.name = "Foot" # ИСПРАВЛЕНО: явное имя
	_foot.mass = 130.0
	_foot.collision_layer = 2
	_foot.collision_mask = 1
	_foot.can_sleep = false
	_foot.contact_monitor = true
	_foot.max_contacts_reported = 4
	_foot.physics_material_override = _mat(1.2)
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(0.45, FOOT_H, 0.6)
	fcs.shape = fsh
	_foot.add_child(fcs)
	var fmi := MeshInstance3D.new()
	var fbm := BoxMesh.new()
	fbm.size = fsh.size
	fmi.mesh = fbm
	_foot.add_child(fmi)

	_upper.position = _hip_pos + b_hip * Vector3(0, -L_UPPER * 0.5, 0)
	_upper.basis = b_hip
	_lower.position = _knee_pos + b_knee * Vector3(0, -L_LOWER * 0.5, 0)
	_lower.basis = b_knee
	_foot.position = _hip_pos + p_foot_center
	_foot.basis = b_foot
	add_child(_upper)
	add_child(_lower)
	add_child(_foot)

	_make_joint(anchor, _upper, _hip_pos, Basis.IDENTITY,
		[0, 2], [REST_HIP_PITCH, REST_HIP_ABDUCT],
		[[-60.0, 60.0], [-10.0, 55.0]], [60000.0, 45000.0])
	_make_joint(_upper, _lower, _knee_pos, b_hip,
		[0], [REST_KNEE], [[-80.0, 45.0]], [60000.0])
	_make_joint(_lower, _foot, _ankle_pos, b_knee,
		[0, 2], [REST_ANKLE_X, REST_ANKLE_Z],
		[[0.0, 100.0], [-70.0, 20.0]], [12000.0, 12000.0])

func _make_joint(a: PhysicsBody3D, b: PhysicsBody3D, pos: Vector3, frame: Basis,
		axes: Array, rest: Array, limits: Array, torques: Array) -> void:
	var j := Generic6DOFJoint3D.new()
	# ИСПРАВЛЕНО: Пути задаются ДО add_child(j), используя явные имена узлов
	j.node_a = NodePath("../" + a.name)
	j.node_b = NodePath("../" + b.name)
	j.position = pos
	j.basis = frame
	add_child(j)
	
	var drv := JointDriverScript.new() # ИСПРАВЛЕНО: использование preload типа
	var ax_arr: Array[int] = []
	var cfg_arr: Array[AxisCfg] = [] # ИСПРАВЛЕНО: использование preload типа
	for i in axes.size():
		ax_arr.append(axes[i])
		var c := AxisCfg.new() # ИСПРАВЛЕНО: использование preload типа
		c.lower_deg = limits[i][0] - rest[i]
		c.upper_deg = limits[i][1] - rest[i]
		c.max_torque = torques[i]
		c.target_deg = 0.0
		cfg_arr.append(c)
	drv.axes = ax_arr
	drv.configs = cfg_arr
	j.add_child(drv)
	_drivers.append(drv)

func _show_keys() -> void:
	DebugDraw2D.set_text("keys", "F1 mode | F2 impulse | F3 damage | F4 friction | F5 drives")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("rig_mode"):
		for d in _drivers:
			for c in d.configs:
				var next := int(c.drive_mode) + 1
				if next > 2:
					next = 0
				c.drive_mode = next
	if event.is_action_pressed("rig_impulse"):
		_foot.apply_impulse(Vector3(0, 0, 2000.0), Vector3.ZERO)
	if event.is_action_pressed("rig_damage"):
		_damaged = not _damaged
		for d in _drivers:
			for c in d.configs:
				c.damage_scale = 0.3 if _damaged else 1.0
	if event.is_action_pressed("rig_friction"):
		_friction_on = not _friction_on
		_ground.physics_material_override.friction = 1.2 if _friction_on else 0.0
	if event.is_action_pressed("rig_drives"):
		for d in _drivers:
			d.enabled = not d.enabled

func _process(_delta: float) -> void:
	if not is_instance_valid(_foot):
		return
	DebugDraw3D.draw_line(_hip_pos, _upper.global_position, Color.YELLOW, 0)
	DebugDraw3D.draw_line(_upper.global_position, _lower.global_position, Color.YELLOW, 0)
	DebugDraw3D.draw_line(_lower.global_position, _foot.global_position, Color.YELLOW, 0)
	for i in _foot.points.size():
		DebugDraw3D.draw_sphere(_foot.points[i], 0.04, Color.GREEN, 0)
		DebugDraw3D.draw_line(_foot.points[i], _foot.points[i] + _foot.normals[i] * 0.4, Color.CYAN, 0)
	DebugDraw3D.draw_sphere(_foot.global_position, 0.06, Color.RED, 0)
	
	var names := ["hip", "knee", "ankle"]
	for di in _drivers.size():
		var d := _drivers[di]
		var a := d.angles_deg()
		var t := d.targets_deg()
		for i in a.size():
			DebugDraw2D.set_text("%s axis%d" % [names[di], d.axes[i]],
				"fact %6.1f  target %6.1f  mode %d" % [a[i], t[i], d.configs[i].drive_mode])
	DebugDraw2D.set_text("stance", str(_foot.stance))
	DebugDraw2D.set_text("foot load N", "%.0f" % _foot.load_n)
	DebugDraw2D.set_text("friction", "ON" if _friction_on else "ZERO")
	DebugDraw2D.set_text("damage", "ON" if _damaged else "off")
	DebugDraw2D.set_text("drives", "ON" if _drivers[0].enabled else "OFF")
