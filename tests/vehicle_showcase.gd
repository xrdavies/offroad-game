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
		{"id":"snow-unimog","vehicle":"unimog","pos":Vector2(130,-370),"yaw":0.2,"low":true,"steer":0.0},
		{"id":"ice-hauler","vehicle":"hauler","pos":Vector2(330,-20),"yaw":0.6,"low":false,"steer":0.25},
		{"id":"alpine-hilux","vehicle":"hilux","pos":Vector2(-270,80),"yaw":0.8,"low":false,"steer":-0.18},
		{"id":"meadow-f150","vehicle":"f150","pos":Vector2(180,310),"yaw":-0.4,"low":false,"steer":0.12}
	] if alpine else [
		{"id":"sand-f150","vehicle":"f150","pos":Vector2(265,-165),"yaw":0.45,"low":false,"steer":0.16},
		{"id":"rock-wrangler","vehicle":"wrangler","pos":Vector2(-521,-345),"yaw":-PI/2,"low":true,"steer":0.0},
		{"id":"forest-hilux","vehicle":"hilux","pos":Vector2(-265,-130),"yaw":0.4,"low":false,"steer":-0.12},
		{"id":"mud-eq246","vehicle":"eq246","pos":Vector2(-80,210),"yaw":0.0,"low":true,"steer":0.08}
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
		Input.action_press("accelerate")
		if absf(float(segment.steer))>0.01:
			Input.action_press("right" if float(segment.steer)>0 else "left")
		await frames(240)
		Input.action_release("accelerate")
		Input.action_release("right")
		Input.action_release("left")
		await frames(30)
	scene.recorder.stop_recording()
	while scene.recorder.finishing:
		await process_frame
	assert(FileAccess.file_exists(scene.recorder.path),"Showcase video must be saved")
	print("SHOWCASE_FILE ",scene.recorder.path)
	print("SHOWCASE_MODE ","alpine" if alpine else "frontier")
	await scene._quit()
