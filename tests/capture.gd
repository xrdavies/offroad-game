extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: Node3D = load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 100:
		await physics_frame
	if args.size()>1:
		var locations := {"yard":Vector2(-61,-10),"river":Vector2(29,-17),"bridge":Vector2(27,-54),"quarry":Vector2(90,18),"relay":Vector2(-3,-89),"scout":Vector2(-6,29),"cliffs":Vector2(-105,-32)}
		if locations.has(args[1]):
			var p: Vector2=locations[args[1]]
			scene.car.reset_to_start(Vector3(p.x,scene.world.height_at(p.x,p.y)+8.0,p.y))
			if args[1]=="scout":
				scene.car.reset_yaw=-1.6
				scene.zoom=18
			if args[1]=="cliffs":
				scene.zoom=40
			for i in 120:
				await physics_frame
		if args[1]=="map":
			scene.map_panel.show()
			scene.map_view.queue_redraw()
		if args[1]=="pause":
			scene._pause(true)
	if args.size()>2 and args[2]=="drive":
		Input.action_press("accelerate")
		for i in 50:
			await physics_frame
	if args.size()>2 and args[2]=="compare":
		# Preserve the previous version's framing for an honest before/after image.
		scene.set_process(false)
		var target: Vector3=scene.car.global_position+Vector3(0,0.5,0)
		scene.camera.size=29
		scene.camera.position=target+Vector3(30,39,33)
		scene.camera.look_at(target)
	await RenderingServer.frame_post_draw
	var path := args[0] if not args.is_empty() else "/tmp/off-road-rider-capture.png"
	var result := root.get_texture().get_image().save_png(path)
	print("CAPTURE ",path," status=",result," fps=",Engine.get_frames_per_second()," draws=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	scene.queue_free()
	await create_timer(0.15).timeout
	quit(result)
