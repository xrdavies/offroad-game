extends SceneTree

var output := "res://build/cockpit-review/after"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output=arg.trim_prefix("--output=")
	call_deferred("_run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scene: Node3D=load("res://main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.ui.hide()
	await frames(120)
	for index in scene.VEHICLES.SPECS.size():
		scene.switch_vehicle(index)
		scene.car.reset_to_start(scene.spawn_point)
		scene.car.reset_yaw=0.8
		await frames(90)
		scene.car.freeze=true
		scene.car.linear_velocity=Vector3.ZERO
		scene.car.angular_velocity=Vector3.ZERO
		scene.car.reset_physics_interpolation()
		scene.camera.set_mode(1)
		scene.camera.set_process(false)
		# All views keep the gameplay driver's eye and FOV; only mouse-look changes.
		for view in [["forward",Vector2.ZERO],["console",Vector2(-0.48,-0.20)],["passenger",Vector2(-1.15,-0.30)],["door",Vector2(1.1,-0.25)]]:
			scene.camera.look=view[1]
			scene.camera._process(0)
			await frames(12)
			await RenderingServer.frame_post_draw
			var path: String=output+"/"+scene.car.spec.id+"-"+view[0]+".png"
			assert(root.get_texture().get_image().save_png(path)==OK)
			print("COCKPIT_REVIEW ",path)
	print("COCKPIT_REVIEW: PASS")
	await scene._quit()
