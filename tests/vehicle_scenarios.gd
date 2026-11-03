extends SceneTree

var results: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func capture(scene: Node3D, title: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String="res://build/vehicle-scenario-"+title+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	print("SCENARIO_CAPTURE ",title," roll=",scene.car.roll_angle_degrees," speed=",scene.car.linear_velocity.length()*3.6)

func vehicle_index(scene: Node3D, id: String) -> int:
	for i in scene.VEHICLES.SPECS.size():
		if scene.VEHICLES.SPECS[i].id==id:
			return i
	return -1

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.ui.show()
	await frames(120)
	var scenarios: Array[Dictionary]=[
		{"id":"sand","map":0,"pos":Vector2(265,-165),"vehicles":["f150","hilux","wrangler"],"yaw":0.45,"low":false},
		{"id":"rock","map":0,"pos":Vector2(-521,-345),"vehicles":["wrangler","unimog","eq246"],"yaw":-PI/2,"low":true},
		{"id":"forest","map":0,"pos":Vector2(-265,-130),"vehicles":["scout","hilux","wc62"],"yaw":0.4,"low":false},
		{"id":"snow","map":2,"pos":Vector2(130,-370),"vehicles":["unimog","hauler","f150"],"yaw":0.2,"low":true},
		{"id":"ice","map":2,"pos":Vector2(330,-20),"vehicles":["hauler","hilux","wc62"],"yaw":0.6,"low":false}
	]
	for scenario in scenarios:
		if scene.map_index!=scenario.map:
			assert(await scene.switch_map(scenario.map))
		await frames(100)
		for id in scenario.vehicles:
			var index:=vehicle_index(scene,id)
			assert(index>=0)
			scene.switch_vehicle(index)
			await frames(70)
			var p: Vector2=scenario.pos
			var car: RigidBody3D=scene.car
			car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+1.8,p.y))
			car.reset_yaw=float(scenario.yaw)
			car.low_range=bool(scenario.low)
			scene.camera.set_mode(2)
			await frames(80)
			Input.action_press("accelerate")
			await frames(90)
			Input.action_release("accelerate")
			await frames(20)
			await capture(scene,scenario.id+"-"+id)
			results.append({"scenario":scenario.id,"vehicle":id,"roll_deg":car.roll_angle_degrees,"max_roll_deg":car.max_roll_angle_degrees,"speed_kmh":car.linear_velocity.length()*3.6,"surface":car.surface_kind})
	var file:=FileAccess.open("res://build/vehicle-scenarios.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(results,"  "))
		file.close()
	print("VEHICLE_SCENARIOS: PASS")
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	quit()
