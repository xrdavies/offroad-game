extends Node3D

const CAR_SCRIPT := preload("res://car.gd")

var car: RigidBody3D
var camera: Camera3D
var speed_label: Label
var state_label: Label
var rng := RandomNumberGenerator.new()
var spawn_point := Vector3(0, 1.4, 18)

var sand := Color("#736953")
var sand_light := Color("#a18a66")
var road := Color("#62574f")
var rust := Color("#825042")
var concrete := Color("#5a5a54")
var plant := Color("#465544")

func _ready() -> void:
	rng.seed = 481516
	_build_environment()
	_build_ground()
	_build_scene_props()
	_build_car()
	_build_ui()

func _process(delta: float) -> void:
	if not is_instance_valid(car):
		return
	var desired_camera := car.global_position + Vector3(0, 11.5, 14.0)
	camera.global_position = camera.global_position.lerp(desired_camera, min(delta * 4.0, 1.0))
	camera.look_at(car.global_position + Vector3(0, 0.5, -2.0), Vector3.UP)
	var speed := car.linear_velocity.length() * 3.6
	speed_label.text = "%03d km/h" % int(speed)
	if car.global_position.y < -8.0:
		car.reset_to_start(spawn_point)
		state_label.text = "RECOVERED — press R anytime to reset"
	elif Input.is_key_pressed(KEY_R):
		car.reset_to_start(spawn_point)
		state_label.text = "RESET TO ROAD"
	else:
		state_label.text = "EXPLORE THE WASTELAND"

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#9e917f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#e4c39d")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("#b9a17e")
	environment.fog_density = 0.0018
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_color = Color("#ffd6a2")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	add_child(sun)

func _build_ground() -> void:
	_add_static_box(Vector3(0, -0.6, 0), Vector3(180, 1, 140), sand, Vector3.ZERO)
	_add_visual_box(Vector3(0, 0.015, 0), Vector3(178, 0.04, 138), sand, Vector3.ZERO)

	# A few broad dirt lanes give the player a readable route without fencing in exploration.
	_add_visual_box(Vector3(0, 0.045, 18), Vector3(150, 0.05, 10), road, Vector3.ZERO)
	_add_visual_box(Vector3(-28, 0.05, -18), Vector3(10, 0.05, 82), road, Vector3.ZERO)
	_add_visual_box(Vector3(28, 0.055, -34), Vector3(70, 0.05, 9), road, Vector3(0, 0.0, 0.07))

	# Low ramps make the first drive feel like off-road driving instead of a flat test floor.
	_add_static_box(Vector3(-15, 0.45, -20), Vector3(9, 0.9, 16), sand_light, Vector3(deg_to_rad(-7), 0, 0))
	_add_static_box(Vector3(20, 0.4, 12), Vector3(13, 0.8, 8), sand_light, Vector3(deg_to_rad(5), 0, deg_to_rad(-4)))
	_add_static_box(Vector3(3, 0.35, -45), Vector3(18, 0.7, 10), sand_light, Vector3(deg_to_rad(-4), 0, 0))

func _build_scene_props() -> void:
	# Distant mesas establish the silhouette while staying cheap to render.
	for data in [
		[Vector3(-68, 3.0, -55), Vector3(24, 6, 18)],
		[Vector3(66, 3.5, -42), Vector3(28, 7, 20)],
		[Vector3(-62, 2.5, 48), Vector3(30, 5, 22)],
		[Vector3(63, 2.5, 52), Vector3(22, 5, 18)],
	]:
		_add_visual_box(data[0], data[1], rust.darkened(0.18), Vector3.ZERO)

	# Scrapyard clusters: simple blocks keep the same hand-made, low-poly language as the reference.
	for i in 34:
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(20.0, 70.0)
		var position := Vector3(cos(angle) * radius, 0.45, sin(angle) * radius)
		if position.distance_to(spawn_point) < 15.0:
			continue
		var size := Vector3(rng.randf_range(1.0, 3.8), rng.randf_range(0.8, 2.4), rng.randf_range(1.0, 3.8))
		var color := rust if i % 3 == 0 else concrete
		_add_static_box(position, size, color, Vector3(0, rng.randf_range(0, TAU), rng.randf_range(-0.12, 0.12)))

	for i in 18:
		var position := Vector3(rng.randf_range(-75, 75), 0.9, rng.randf_range(-58, 58))
		if abs(position.x) < 12.0 or abs(position.z - spawn_point.z) < 8.0:
			continue
		_add_cactus(position)

	for data in [
		[Vector3(-44, 2.0, -5), Vector3(3.0, 4.0, 3.0)],
		[Vector3(-49, 1.3, -5), Vector3(2.2, 2.6, 2.2)],
		[Vector3(48, 1.8, -22), Vector3(3.2, 3.6, 3.2)],
	]:
		_add_visual_box(data[0], data[1], concrete, Vector3(0, 0.2, 0))

func _build_car() -> void:
	car = RigidBody3D.new()
	car.name = "PlayerCar"
	car.set_script(CAR_SCRIPT)
	car.position = spawn_point
	add_child(car)

	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.fov = 62.0
	camera.position = spawn_point + Vector3(0, 11.5, 14.0)
	camera.current = true
	add_child(camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "DUSTLINE"
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("#fff1d2"))
	layer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "FREE ROAM / PROTOTYPE 01"
	subtitle.position = Vector2(30, 58)
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color("#f0d2a3"))
	layer.add_child(subtitle)

	speed_label = Label.new()
	speed_label.text = "000 km/h"
	speed_label.position = Vector2(1080, 28)
	speed_label.add_theme_font_size_override("font_size", 22)
	speed_label.add_theme_color_override("font_color", Color("#fff1d2"))
	layer.add_child(speed_label)

	var controls := Label.new()
	controls.text = "WASD / ARROWS  DRIVE     SPACE  HANDBRAKE     R  RESET"
	controls.position = Vector2(30, 670)
	controls.add_theme_font_size_override("font_size", 13)
	controls.add_theme_color_override("font_color", Color("#f6dfb5"))
	layer.add_child(controls)

	state_label = Label.new()
	state_label.text = "EXPLORE THE WASTELAND"
	state_label.position = Vector2(30, 100)
	state_label.add_theme_font_size_override("font_size", 12)
	state_label.add_theme_color_override("font_color", Color("#e0c39a"))
	layer.add_child(state_label)

func _add_static_box(position: Vector3, size: Vector3, color: Color, rotation: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.rotation = rotation
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _material(color)
	body.add_child(visual)
	return body

func _add_visual_box(position: Vector3, size: Vector3, color: Color, rotation: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = position
	visual.rotation = rotation
	visual.material_override = _material(color)
	add_child(visual)
	return visual

func _add_cactus(position: Vector3) -> void:
	var stem := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.24
	mesh.bottom_radius = 0.34
	mesh.height = 1.8
	mesh.radial_segments = 7
	stem.mesh = mesh
	stem.position = position
	stem.material_override = _material(plant)
	add_child(stem)
	var arm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.75, 0.22, 0.22)
	arm.mesh = arm_mesh
	arm.position = position + Vector3(0.25, 0.25, 0)
	arm.material_override = _material(plant.lightened(0.08))
	add_child(arm)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	return material
