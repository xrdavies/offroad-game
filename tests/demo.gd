extends SceneTree

var failures: Array[String]=[]
var report: Array[Dictionary]=[]

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func action(scene: Node, name: String) -> void:
	var event:=InputEventAction.new()
	event.action=name
	event.pressed=true
	scene._unhandled_input(event)

func _run() -> void:
	var capture:=OS.get_cmdline_user_args().has("--capture")
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await physics_frame
	check(not scene.demo.active and not scene.car.autopilot_enabled,"Normal startup stays manual")
	scene.recorder.finishing=true
	scene.start_demo(false)
	check(not scene.demo.active,"Do not start demo while saving a video")
	scene.recorder.finishing=false
	scene.start_demo(false)
	var demo: Node=scene.demo
	check(demo.active and scene.car.autopilot_enabled,"Demo enables real vehicle controls")
	var total_frames:=0
	var pause_checked:=false
	var seen_cameras: Dictionary={}
	for index in demo.ROUTES.size():
		var route: Dictionary=demo.ROUTES[index]
		var max_speed:=0.0
		var distance:=0.0
		var max_roll:=0.0
		var route_time:=0.0
		var previous:=Vector2(scene.car.position.x,scene.car.position.z)
		var captured:=false
		var completed_before: int=demo.completed_routes
		while demo.route_index==index and demo.active:
			await physics_frame
			total_frames+=1
			if demo.transitioning or demo.route_index!=index:
				continue
			var p:=Vector2(scene.car.position.x,scene.car.position.z)
			if demo.elapsed>1.5:
				distance+=p.distance_to(previous)
			previous=p
			max_speed=maxf(max_speed,scene.car.linear_velocity.length()*3.6)
			max_roll=maxf(max_roll,absf(scene.car.roll_angle_degrees))
			route_time=demo.elapsed
			seen_cameras[scene.camera.mode]=true
			if not pause_checked and demo.elapsed>4.0:
				pause_checked=true
				scene._pause(true)
				var before: float=demo.elapsed
				await create_timer(0.12,true).timeout
				check(is_equal_approx(before,demo.elapsed),"Pause freezes autopilot timers")
				scene._pause(false)
			if capture and demo.elapsed>10 and not captured:
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png("res://build/demo-%02d.png"%index)==OK,"Capture demo scene")
				captured=true
			if total_frames>60*700:
				check(false,"Demo must finish a complete loop")
				demo.stop()
				break
		while demo.transitioning:
			await process_frame
		check(max_speed>8.0,"Car actually drives: "+route.name)
		check(distance>30.0,"Route travels more than 30 metres: "+route.name)
		check(max_roll<65.0,"Car stays upright: "+route.name)
		check(demo.completed_routes==completed_before+1,"Route reaches its destination: "+route.name)
		report.append({"route":route.name,"vehicle":route.vehicle,"map":route.map,"max_speed_kmh":max_speed,"distance_m":distance,"max_roll_deg":max_roll,"duration_s":route_time,"completed":demo.completed_routes==completed_before+1})
		print("DEMO_RESULT ",JSON.stringify(report.back()))
		if not demo.active:
			break
	check(demo.completed_routes==demo.ROUTES.size(),"All ten routes reach their destination")
	check(demo.route_index==0 and scene.map_index==0,"Demo loops back to the first map")
	check(demo.recoveries==0,"All curated routes finish without stuck recovery")
	check(seen_cameras.has(2) and seen_cameras.has(3) and seen_cameras.has(1),"Chase, side and cockpit views are shown")
	action(scene,"accelerate")
	check(not demo.active and not scene.car.autopilot_enabled and scene.car.autopilot_input==Vector2.ZERO,"Manual input takes over and releases demo controls")
	for i in 100:
		await physics_frame
	var start: Vector3=scene.car.position
	Input.action_press("accelerate")
	for i in 90:
		await physics_frame
	Input.action_release("accelerate")
	check(scene.car.position.distance_to(start)>3,"Manual driving works after takeover")
	scene._pause(true)
	if capture:
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/demo-menu.png")==OK,"Capture demo menu")
	scene.demo_button.pressed.emit()
	check(demo.active and not paused,"Menu restarts demo and resumes driving")
	if capture:
		await create_timer(0.4).timeout
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Demo menu starts fullscreen")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://build/demo-fullscreen.png")==OK,"Capture fullscreen demo")
		action(scene,"fullscreen")
		check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"F11 exits fullscreen")
	scene.car.freeze=true
	scene.car.linear_velocity=Vector3.ZERO
	scene.car.angular_velocity=Vector3.ZERO
	for i in 440:
		await physics_frame
	check(demo.recoveries==1 and demo.route_index==1,"Stuck vehicle advances to the next route")
	demo.route_index=4
	demo.advance()
	demo.stop()
	while demo.transitioning:
		await process_frame
	check(not scene.car.autopilot_enabled and not demo.active,"Stopping during map loading cancels the next drive")
	scene.start_demo(false)
	while demo.transitioning:
		await process_frame
	action(scene,"demo")
	check(not demo.active and not scene.car.autopilot_enabled,"F8 stops demo")
	action(scene,"hide_hud")
	action(scene,"hide_hud")
	check(not scene.demo_label.visible,"Restoring HUD does not show a stopped demo label")
	var file:=FileAccess.open("res://build/demo-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"routes":report,"failures":failures},"  "))
	file.close()
	print("DEMO: ","PASS" if failures.is_empty() else failures)
	scene.set_process(false)
	paused=true
	for player in scene.find_children("*","AudioStreamPlayer",true,false):
		player.stop()
		player.stream=null
	OS.delay_msec(200)
	scene.queue_free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
