extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.recorder.message.connect(func(value: String): print("RECORDER_STATUS ",value))
	for i in 120:
		await physics_frame
	scene.camera.set_mode(1)
	scene.car.reset_to_start(Vector3(-160,scene.world.height_at(-160,60)+1.7,60))
	scene.car.reset_yaw=0
	for i in 120:
		await physics_frame
	scene._set_film_mode(1)
	scene.recorder.start_recording(scene.film_view)
	assert(scene.recorder.active,"Recorder must start")
	Input.action_press("accelerate")
	var peak := 0.0
	var begin := Time.get_ticks_msec()
	var render_frames := 0
	while Time.get_ticks_msec()-begin<8000:
		await process_frame
		render_frames+=1
		peak=maxf(peak,scene.car.linear_velocity.length()*3.6)
		if Time.get_ticks_msec()-begin>3000 and scene.film_mode==1:
			scene._set_film_mode(2)
		if Time.get_ticks_msec()-begin>5500 and scene.film_mode==2:
			scene._set_film_mode(3)
	Input.action_release("accelerate")
	scene.recorder.stop_recording()
	while scene.recorder.finishing:
		await process_frame
	assert(FileAccess.file_exists(scene.recorder.path),"Video must be saved")
	print("RECORDING_FILE ",scene.recorder.path)
	print("RECORDING peak_kmh=",peak," average_render_fps=",render_frames/8.0," dropped_capture_frames=",scene.recorder.dropped_frames)
	assert(peak>80,"Recording test must include highway-speed driving")
	# The second clip exercises restart, current-view capture, pause and quit finalization.
	scene._set_film_mode(0)
	scene.recorder.start_recording(root)
	assert(scene.recorder.active,"Recorder must restart successfully")
	await create_timer(1.5).timeout
	scene._pause(true)
	await create_timer(0.5).timeout
	print("RECORDING_RESTART_FILE ",scene.recorder.path)
	await scene._quit()
	assert(FileAccess.file_exists(scene.recorder.path),"Quit must finish saving the restarted recording")
	print("RECORDING_QUIT_SAVED ",scene.recorder.path)
