extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(120)
	var world: Node3D=scene.world
	check(world.SIZE==Vector2(720,600),"Expanded map bounds must match recovery and navigation")
	for zone in world.REGIONS.ZONES:
		var p: Vector2=zone.center+Vector2(2,-2)
		var at := Vector3(p.x,world.height_at(p.x,p.y)+1,p.y)
		check(world.surface_at(at)==zone.surface,"Region must apply its surface physics: "+zone.id)
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*10,at-Vector3.UP*3)
		var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(),"Expanded region must have collision: "+zone.id)
		if not hit.is_empty():
			check(absf(hit.position.y-world.height_at(p.x,p.y))<0.25,"Visible and physical terrain must agree: "+zone.id)
		for trail in world.REGIONS.TRAILS:
			for point in trail:
				check(absf(point.x)<world.SIZE.x-10 and absf(point.y)<world.SIZE.y-10,"Trails must stay within boundaries")
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		var car: RigidBody3D=scene.car
		var at := Vector3(-180,world.height_at(-180,30)+1.7,30)
		car.reset_to_start(at)
		car.reset_yaw=0
		await frames(150)
		check(car.grounded_wheels==car.rays.size(),"All wheels must settle: "+car.spec.id)
		check(car.linear_velocity.length()<1,"Vehicle must be stable: "+car.spec.id)
		Input.action_press("accelerate")
		await frames(120)
		Input.action_release("accelerate")
		check(car.position.distance_to(at)>8,"Each vehicle must drive: "+car.spec.id)
		scene.camera.set_mode(1)
		await process_frame
		scene.camera._process(1.0/60)
		var expected: Vector3=car.get_global_transform_interpolated()*car.spec.seat
		check(scene.camera.global_position.distance_to(expected)<0.02,"Driver camera must remain at interpolated seat: "+car.spec.id)
		car.reset_to_start(Vector3(-80,world.height_at(-80,210)+1.7,210))
		car.reset_yaw=PI/2
		car.low_range=true
		await frames(120)
		var start: Vector3=car.position
		Input.action_press("accelerate")
		await frames(180)
		Input.action_release("accelerate")
		check(car.position.distance_to(start)>5,"Low range must make progress through mud: "+car.spec.id)
		check(car.linear_velocity.length()<car.spec.speed*0.5,"Low range must limit speed: "+car.spec.id)
	for mode in range(5):
		scene.camera.set_mode(mode)
		scene.camera._process(1.0/60)
		check(scene.camera.global_position.is_finite(),"All camera modes must produce valid transforms")
	scene._set_film_mode(3)
	check(scene.film_camera.mode==4,"Independent recording camera must use selected drone mode")
	check(scene.camera!=scene.film_camera,"Filming must not replace the driving camera")
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=scene.map_view.size*0.5
	scene.map_view._gui_input(event)
	check(scene.waypoint.length()<0.01,"Map center click must create a world-space waypoint")
	print("EXPEDITION: ","PASS" if failures.is_empty() else failures)
	# Audio runs on wall time even when the test uses --fixed-fps.
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	OS.delay_msec(100)
	quit(0 if failures.is_empty() else 1)
