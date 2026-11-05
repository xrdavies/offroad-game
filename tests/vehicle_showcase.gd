extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await process_frame

func vehicle_index(scene: Node3D, id: String) -> int:
	for i in scene.VEHICLES.SPECS.size():
		if scene.VEHICLES.SPECS[i].id==id:
			return i
	return -1

func _run() -> void:
	var alpine:=OS.get_cmdline_user_args().has("--alpine")
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(120)
	if alpine:
		assert(await scene.switch_map(2))
		await frames(120)
	var segments: Array=[
		{"id":"snow-unimog","vehicle":"unimog","pos":Vector2(30,-323),"yaw":-0.912,"low":true},
		{"id":"ice-hauler","vehicle":"hauler","pos":Vector2(315,25),"yaw":-0.322,"low":false},
		{"id":"alpine-hilux","vehicle":"hilux","pos":Vector2(235,212),"yaw":2.63,"low":false},
		{"id":"meadow-f150","vehicle":"f150","pos":Vector2(180,310),"yaw":1.04,"low":false}
	] if alpine else [
		{"id":"sand-f150","vehicle":"f150","pos":Vector2(265,-165),"yaw":-1.03,"low":false},
		{"id":"rock-wrangler","vehicle":"wrangler","pos":Vector2(-521,-345),"yaw":-PI/2,"low":true},
		{"id":"forest-hilux","vehicle":"hilux","pos":Vector2(-267.5,-140),"yaw":0.245,"low":false},
		{"id":"mud-eq246","vehicle":"eq246","pos":Vector2(-80,145),"yaw":PI,"low":true},
		{"id":"marsh-wc62","vehicle":"wc62","pos":Vector2(155,150),"yaw":-2.509,"low":true}
	]
	scene._set_film_mode(0)
	scene.camera.set_mode(2)
	scene.recorder.start_recording(root)
	assert(scene.recorder.active,"Showcase recorder must start")
	for segment in segments:
		var index:=vehicle_index(scene,segment.vehicle)
		assert(index>=0)
		scene.switch_vehicle(index)
		await frames(45)
		var p: Vector2=segment.pos
		var car: RigidBody3D=scene.car
		car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+1.8,p.y))
		car.reset_yaw=float(segment.yaw)
		car.low_range=bool(segment.low)
		scene.camera.set_mode(2 if segment.id not in ["rock-wrangler","mud-eq246"] else 3)
		await frames(45)
		var start: Vector3=car.position
		car.autopilot_enabled=true
		var target_speed:=7.0 if segment.id=="snow-unimog" else 3.5 if car.low_range else 6.0
		var max_speed:=0.0
		for tick in (360 if segment.id=="snow-unimog" else 240):
			var speed: float=car.linear_velocity.dot(-car.global_basis.z)
			var steer: float=clampf(wrapf(car.rotation.y-float(segment.yaw),-PI,PI)*2.0,-0.6,0.6)
			car.autopilot_input=Vector2(steer,clampf((target_speed-speed)*0.5,-0.3,0.8))
			if tick==120: scene.camera.set_mode(1)
			await frames(1)
			max_speed=maxf(max_speed,car.linear_velocity.length()*3.6)
		car.autopilot_input=Vector2.ZERO
		car.autopilot_enabled=false
		print("SHOWCASE_SEGMENT ",segment.id," distance=",car.position.distance_to(start)," max_kmh=",max_speed)
		if car.position.distance_to(start)<=5.0 or max_speed<=6.0:
			push_error("Showcase vehicle did not drive: "+segment.id)
			scene.recorder.stop_recording()
			while scene.recorder.finishing: await process_frame
			scene.set_process(false)
			car.set_physics_process(false)
			car.stop_audio()
			OS.delay_msec(100)
			scene.queue_free()
			await process_frame
			quit(1)
			return
		await frames(30)
	scene.recorder.stop_recording()
	while scene.recorder.finishing:
		await process_frame
	assert(FileAccess.file_exists(scene.recorder.path),"Showcase video must be saved")
	print("SHOWCASE_FILE ",scene.recorder.path)
	print("SHOWCASE_MODE ","alpine" if alpine else "frontier")
	await scene._quit()
