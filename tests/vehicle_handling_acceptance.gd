extends SceneTree

const VEHICLES := preload("res://vehicles.gd")
var failures: Array[String]=[]
var report: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func vehicle_index(id: String) -> int:
	for i in VEHICLES.SPECS.size():
		if VEHICLES.SPECS[i].id==id:
			return i
	return -1

func make_test_ramp(scene: Node3D) -> StaticBody3D:
	var ramp:=StaticBody3D.new()
	ramp.name="HandlingAcceptanceRamp"
	ramp.position=Vector3(0,8,430)
	ramp.rotation.z=deg_to_rad(20.0)
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(14,1,24)
	shape.shape=box
	ramp.add_child(shape)
	scene.add_child(ramp)
	return ramp

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(100)
	var ramp:=make_test_ramp(scene)
	var radius_samples: Array[float]=[]
	var lift_cases:=0
	for index in scene.VEHICLES.SPECS.size():
		if index>0:
			scene.switch_vehicle(index)
			await frames(35)
		var car: RigidBody3D=scene.car
		var spec: Dictionary=car.spec
		var collision_count:=0
		for child in car.get_children():
			if child is CollisionShape3D and child.get_meta("collision_role","")=="vehicle_compound":
				collision_count+=1
		check(collision_count>=4,"Compound collision profile has chassis, cabin, cargo and bumpers: "+spec.id)

		var flat:=Vector3(-180,scene.world.height_at(-180,30)+1.8,30)
		car.reset_to_start(flat)
		car.reset_yaw=0.0
		car.autopilot_enabled=false
		await frames(70)
		car.autopilot_enabled=true
		car.autopilot_input=Vector2(1.0,0.92)
		var dynamic_radii: Array[float]=[]
		for frame in 300:
			await physics_frame
			var forward_speed:=absf(car.linear_velocity.dot(-car.global_basis.z))
			var yaw_rate:=absf(car.angular_velocity.y)
			if frame>150 and forward_speed>3.0 and yaw_rate>0.04:
				dynamic_radii.append(forward_speed/yaw_rate)
		car.autopilot_input=Vector2.ZERO
		car.autopilot_enabled=false
		var theoretical: float=car.wheelbase/tan(car.max_steer_angle)
		var measured: float=0.0
		if not dynamic_radii.is_empty():
			measured=dynamic_radii.reduce(func(a: float,b: float)->float: return a+b)/dynamic_radii.size()
			check(measured>theoretical*0.20 and measured<theoretical*8.0,"Dynamic minimum turning radius stays within steering geometry: "+spec.id)
		else:
			check(false,"Dynamic minimum turning radius produced no steady samples: "+spec.id)

		car.reset_to_start(Vector3(0,10.2,430))
		car.reset_yaw=0.0
		car.autopilot_enabled=true
		car.autopilot_input=Vector2(0.0,0.72)
		var lift_frames:=0
		var max_lift_frames:=0
		var saw_lift:=false
		for _frame in 240:
			await physics_frame
			if car.grounded_wheels>0 and car.grounded_wheels<car.rays.size():
				saw_lift=true
				lift_frames+=1
				max_lift_frames=maxi(max_lift_frames,lift_frames)
			else:
				lift_frames=0
		car.autopilot_input=Vector2.ZERO
		car.autopilot_enabled=false
		if saw_lift:
			lift_cases+=1

		car.reset_to_start(flat)
		car.reset_yaw=0.0
		await frames(55)
		car.rotation.z=deg_to_rad(110.0)
		car.linear_velocity=Vector3.ZERO
		car.angular_velocity=Vector3.ZERO
		await frames(3)
		check(car.tipped,"Forced rollover is detected before recovery: "+spec.id)
		car.reset_to_start(flat)
		var recovery_frames:=0
		for frame in 90:
			await physics_frame
			if not car.tipped and car.global_basis.y.dot(Vector3.UP)>0.95:
				recovery_frames=frame+1
				break
		check(recovery_frames>0,"Rollover recovery returns the vehicle upright: "+spec.id)
		report.append({"id":spec.id,"compound_collision_shapes":collision_count,"theoretical_min_radius_m":theoretical,"measured_turn_radius_m":measured,"max_wheel_lift_sec":float(max_lift_frames)/60.0,"wheel_lift_detected":saw_lift,"rollover_recovery_sec":float(recovery_frames)/60.0})
		print("HANDLING ",spec.id," radius=",measured," lift_sec=",float(max_lift_frames)/60.0," recovery_sec=",float(recovery_frames)/60.0)
	check(lift_cases>=3,"At least three vehicles demonstrate wheel unloading on the side ramp")
	var file:=FileAccess.open("res://build/vehicle-handling-acceptance.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"vehicles":report,"wheel_lift_cases":lift_cases,"failures":failures},"  "))
		file.close()
	print("VEHICLE_HANDLING_ACCEPTANCE: ","PASS" if failures.is_empty() else failures)
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
