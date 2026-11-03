extends SceneTree

var failures: Array[String]=[]
var report: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func make_test_ramp() -> StaticBody3D:
	var ramp:=StaticBody3D.new()
	ramp.name="VehicleDynamicsRamp"
	ramp.position=Vector3(0,8,430)
	ramp.rotation.z=deg_to_rad(20.0)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(14,1,24)
	shape.shape=box
	ramp.add_child(shape)
	root.add_child(ramp)
	return ramp

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(120)
	var ramp:=make_test_ramp()
	var com_heights: Array[float]=[]
	var steer_angles: Array[float]=[]
	for index in scene.VEHICLES.SPECS.size():
		if index>0:
			scene.switch_vehicle(index)
		var car: RigidBody3D=scene.car
		var spec: Dictionary=car.spec
		var expected_angle:=deg_to_rad(float(spec.max_steer_deg))
		com_heights.append(float(spec.center_of_mass.y))
		steer_angles.append(float(spec.max_steer_deg))
		check(car.center_of_mass.is_equal_approx(spec.center_of_mass),"Vehicle COM applied: "+spec.id)
		check(is_equal_approx(car.max_steer_angle,expected_angle),"Vehicle steering angle applied: "+spec.id)
		var flat:=Vector3(-180,scene.world.height_at(-180,30)+1.7,30)
		car.reset_to_start(flat)
		car.reset_yaw=0
		await frames(130)
		check(car.grounded_wheels==car.rays.size(),"All wheels settle before steering test: "+spec.id)
		Input.action_press("right")
		await frames(45)
		Input.action_release("right")
		check(absf(car.current_steer_angle)>expected_angle*0.95,"Input reaches full steering angle: "+spec.id)
		check(absf(car.wheels[0].rotation.y)>expected_angle*0.75,"Front wheel shows vehicle-specific angle: "+spec.id)
		await frames(20)
		car.reset_to_start(Vector3(0,10.2,430))
		car.reset_yaw=0
		await frames(180)
		var ramp_roll: float=float(car.max_roll_angle_degrees)
		check(is_finite(ramp_roll),"Roll telemetry remains finite: "+spec.id)
		report.append({"id":spec.id,"com_y":float(spec.center_of_mass.y),"max_steer_deg":float(spec.max_steer_deg),"flat_roll_deg":car.max_roll_angle_degrees,"ramp_roll_deg":ramp_roll,"tipped":car.tipped})
		print("DYNAMICS ",spec.id," com_y=",spec.center_of_mass.y," max_steer=",spec.max_steer_deg," ramp_roll=",ramp_roll," tipped=",car.tipped)
		Input.action_release("accelerate")
		Input.action_release("right")
	check(com_heights.max()-com_heights.min()>0.25,"Vehicle COM heights must differ across the fleet")
	check(steer_angles.max()-steer_angles.min()>=12.0,"Vehicle steering limits must differ across the fleet")
	var report_file:=FileAccess.open("res://build/vehicle-dynamics.json",FileAccess.WRITE)
	if report_file:
		report_file.store_string(JSON.stringify({"vehicles":report,"failures":failures},"  "))
		report_file.close()
	print("VEHICLE_DYNAMICS: ","PASS" if failures.is_empty() else failures)
	ramp.queue_free()
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
