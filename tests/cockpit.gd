extends SceneTree

var failures: Array[String] = []
var capture := "--capture" in OS.get_cmdline_user_args()

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func shot(title: String) -> void:
	await frames(90)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/cockpit-"+title+".png") == OK, "Save actual viewport capture")
	print("COCKPIT_RENDER ",title," fps=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _run() -> void:
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await frames(120)
	for index in scene.VEHICLES.SPECS.size():
		if index > 0:
			scene.switch_vehicle(index)
		scene.car.reset_to_start(scene.spawn_point)
		scene.car.reset_yaw = 0.8
		await frames(90)
		var car: RigidBody3D = scene.car
		for sample in [[0.0,135.0,"000"],[70.0,0.0,"070"],[140.0,-135.0,"140"],[200.0,-135.0,"200"]]:
			car._update_dashboard(sample[0])
			check(is_equal_approx(car.speed_needle.rotation.z,deg_to_rad(sample[1])),"Calibrated speed needle: "+car.spec.id)
			check(car.speed_readout.text == sample[2],"Readable live speed: "+car.spec.id)
		# A positive yaw faces west: its pointer must move left of north.
		check(is_equal_approx(car.heading_needle.rotation.z,car.rotation.y),"Compass follows vehicle heading")
		check(car.heading_needle.basis.y.x < -0.6,"West heading must point toward W on the fixed dial")
		Input.action_press("right")
		await frames(12)
		Input.action_release("right")
		check(car.steering_wheel.rotation.z < -0.5,"Detailed steering mesh responds to input")
		await frames(50)
		scene.camera.set_mode(1)
		scene.camera._process(0)
		check(not scene.camera.get_cull_mask_value(2),"Opaque exterior glass stays hidden from driver")
		var wheel_center: Vector3 = car.steering_wheel.global_position
		check(not scene.camera.is_position_behind(wheel_center),"Steering wheel stays in front of the driver")
		if capture:
			# Hold the parked vehicle still while inspecting a fixed mouse-look angle.
			car.freeze = true
			car.linear_velocity = Vector3.ZERO
			car.angular_velocity = Vector3.ZERO
			car.reset_physics_interpolation()
			scene.ui.show()
			await shot(car.spec.id+"-driving")
			scene.ui.hide()
			await shot(car.spec.id)
			if index == 0:
				scene.camera.set_process(false)
				scene.camera.look = Vector2(-0.58,-0.20)
				scene.camera._process(0)
				await shot("interior")
				scene.camera.look = Vector2(-1.15,-0.30)
				scene.camera._process(0)
				await shot("seats")
				scene.camera.set_process(true)
			scene.camera.set_mode(3)
			await shot(car.spec.id+"-exterior")
	print("COCKPIT: ","PASS" if failures.is_empty() else failures)
	scene.set_process(false)
	paused = true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream = null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	OS.delay_msec(100)
	quit(0 if failures.is_empty() else 1)
