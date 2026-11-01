extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func frames(count: int) -> void:
	for i in count:
		await physics_frame
func capture(scene: Node3D, title: String) -> void:
	await frames(60)
	await RenderingServer.frame_post_draw
	var path := "res://build/"+title+".png"
	var result := root.get_texture().get_image().save_png(path)
	assert(result==OK)
	print("RENDER ",title," fps=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(150)
	await capture(scene,"expedition-service")
	scene.camera.set_mode(1)
	await capture(scene,"expedition-cockpit")
	for zone in scene.world.REGIONS.ZONES:
		var p: Vector2=zone.center
		scene.car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+1.7,p.y))
		scene.camera.set_mode(4)
		await frames(100)
		Input.action_press("handbrake")
		await capture(scene,"expedition-"+zone.id)
		Input.action_release("handbrake")
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		scene.car.reset_to_start(Vector3(-180,scene.world.height_at(-180,30)+1.7,30))
		scene.car.reset_yaw=0.6
		scene.camera.set_mode(3)
		await frames(120)
		await capture(scene,"expedition-"+scene.car.spec.id)
	scene.map_panel.show()
	await capture(scene,"expedition-map")
	scene.map_panel.hide()
	scene._toggle_garage()
	await capture(scene,"expedition-garage")
	scene.queue_free()
	await create_timer(0.2).timeout
	quit()
