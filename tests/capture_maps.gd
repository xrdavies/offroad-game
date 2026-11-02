extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func shot(scene: Node3D, title: String) -> void:
	await frames(45)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://build/map-"+title+".png")==OK)
	print("MAP_RENDER ",title," fps=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(100)
	scene.switch_vehicle(4)
	var locations := [
		[["ruins",Vector2(-520,80),Vector3(68,40,85)], ["crawl",Vector2(-520,-345),Vector3(12,6,15)], ["lake",Vector2(-445,350),Vector3(100,52,130)]],
		[["beach",Vector2(-462,80),Vector3(58,35,70)], ["harbor",Vector2(-260,-210),Vector3(70,42,95)], ["dunes",Vector2(290,-260),Vector3(70,30,60)]],
		[["snow",Vector2(130,-400),Vector3(90,55,95)], ["ice",Vector2(330,-20),Vector3(90,50,95)], ["forest",Vector2(-270,80),Vector3(55,27,50)]]]
	for index in 3:
		await scene.switch_map(index)
		scene.ui.hide()
		for location in locations[index]:
			var p: Vector2=location[1]
			scene.car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+1.7,p.y))
			scene.car.freeze=false
			await frames(100)
			scene.car.freeze=true
			scene.car.linear_velocity=Vector3.ZERO
			scene.car.reset_physics_interpolation()
			scene.camera.set_process(false)
			scene.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
			scene.camera.fov=58
			scene.camera.set_cull_mask_value(2,true)
			var target: Vector3=scene.car.position+Vector3.UP*1.0
			scene.camera.position=target+location[2]
			scene.camera.look_at(target)
			await shot(scene,scene.world.map_spec.id+"-"+location[0])
			scene.camera.set_process(true)
		scene.ui.show()
		scene.map_panel.show()
		await shot(scene,scene.world.map_spec.id+"-navigation")
		scene.map_panel.hide()
	scene._show_destinations()
	await shot(scene,"destinations")
	scene.destinations_panel.hide()
	scene._pause(false)
	scene._toggle_garage()
	var scroll: ScrollContainer=scene.garage_panel.get_child(0).get_child(1)
	scroll.scroll_vertical=10000
	await shot(scene,"garage-bottom")
	print("MAP_CAPTURE: PASS")
	await scene._quit()
