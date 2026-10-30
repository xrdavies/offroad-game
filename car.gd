extends RigidBody3D

## A deliberately small arcade vehicle controller for the first playable pass.
## The body is physical, but the grip and steering are tuned for easy exploration.

@export var engine_force := 12000.0
@export var max_speed := 25.0
@export var steering_strength := 3.2
@export var tire_grip := 2.8
@export var brake_strength := 5.0

var start_position := Vector3.ZERO
var wheel_radius := 0.42
var wheel_spin := 0.0
var wheel_pivots: Array[Node3D] = []
var wheel_meshes: Array[MeshInstance3D] = []
var front_steer := 0.0

func _ready() -> void:
	mass = 900.0
	linear_damp = 0.18
	angular_damp = 1.4
	continuous_cd = true
	start_position = global_position
	_build_collision()
	_build_visuals()

func _physics_process(delta: float) -> void:
	var throttle := _axis(KEY_W, KEY_S, KEY_UP, KEY_DOWN)
	var steer := _axis(KEY_D, KEY_A, KEY_RIGHT, KEY_LEFT)
	var handbrake := Input.is_key_pressed(KEY_SPACE)
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var forward_speed := linear_velocity.dot(forward)

	if abs(forward_speed) < max_speed or sign(throttle) != sign(forward_speed):
		apply_central_force(forward * throttle * engine_force)

	var lateral_speed := linear_velocity.dot(right)
	var grip := tire_grip * (0.18 if handbrake else 1.0)
	apply_central_force(-right * lateral_speed * grip * mass)

	if handbrake:
		apply_central_force(-linear_velocity * brake_strength * mass * 0.18)
	elif abs(throttle) < 0.05:
		apply_central_force(-linear_velocity * mass * 0.045)

	var steer_amount: float = clampf(abs(forward_speed) / 4.0, 0.0, 1.0)
	var travel_direction: float = 1.0
	if forward_speed < -0.1:
		travel_direction = -1.0
	var yaw_torque: float = steer * steering_strength * steer_amount * travel_direction
	apply_torque(Vector3.UP * yaw_torque * mass * 0.12)

	front_steer = lerp(front_steer, steer * 0.48, min(delta * 8.0, 1.0))
	wheel_spin += forward_speed * delta / wheel_radius
	_update_wheels()

func _axis(positive: Key, negative: Key, positive_alt: Key, negative_alt: Key) -> float:
	var value := 0.0
	if Input.is_key_pressed(positive) or Input.is_key_pressed(positive_alt):
		value += 1.0
	if Input.is_key_pressed(negative) or Input.is_key_pressed(negative_alt):
		value -= 1.0
	return value

func reset_to_start(at: Vector3 = start_position) -> void:
	freeze = true
	global_position = at + Vector3.UP * 1.2
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = false
	sleeping = false

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 0.78, 3.6)
	shape.shape = box
	shape.position.y = 0.55
	add_child(shape)

func _build_visuals() -> void:
	var body_material := _material(Color("#3e6863"))
	var dark_material := _material(Color("#202326"))
	var accent_material := _material(Color("#bd8150"))

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.9, 0.8, 3.7)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = body_mesh
	body.position.y = 0.55
	body.material_override = body_material
	add_child(body)

	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.45, 0.52, 1.55)
	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0, 1.15, 0.18)
	cabin.material_override = dark_material
	add_child(cabin)

	var hood_mesh := BoxMesh.new()
	hood_mesh.size = Vector3(1.5, 0.14, 0.9)
	var hood := MeshInstance3D.new()
	hood.name = "Hood"
	hood.mesh = hood_mesh
	hood.position = Vector3(0, 1.0, -1.1)
	hood.material_override = accent_material
	add_child(hood)

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = wheel_radius
	wheel_mesh.bottom_radius = wheel_radius
	wheel_mesh.height = 0.34
	wheel_mesh.radial_segments = 12
	wheel_mesh.material = dark_material
	for data in [
		{ "position": Vector3(-1.0, 0.42, -1.22), "front": true },
		{ "position": Vector3(1.0, 0.42, -1.22), "front": true },
		{ "position": Vector3(-1.0, 0.42, 1.22), "front": false },
		{ "position": Vector3(1.0, 0.42, 1.22), "front": false },
	]:
		var pivot := Node3D.new()
		pivot.position = data.position
		add_child(pivot)
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI / 2.0
		pivot.add_child(wheel)
		wheel_pivots.append(pivot)
		wheel_meshes.append(wheel)

func _update_wheels() -> void:
	for i in wheel_pivots.size():
		wheel_pivots[i].rotation.y = front_steer if i < 2 else 0.0
		wheel_meshes[i].rotation.x = wheel_spin

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
